#!/usr/bin/env bash
# Test the per-monitor workspace indicator without touching the running session.
#
# Starts a nested Hyprland in a throwaway HOME, opens a virtual second monitor
# (a headless output), runs only the Pebble bar and denon.workspaces in it, and
# captures screenshots of both monitors. The real Omarchy shell, config and
# state are never touched.
#
# Usage:
#   tests/multi-monitor-workspaces.sh              # screenshots in /tmp, clean up
#   tests/multi-monitor-workspaces.sh --out DIR    # choose where screenshots go
#   tests/multi-monitor-workspaces.sh --keep       # keep logs and temp HOME
#
# Requires: Hyprland, hyprctl, grim, jq, quickshell (all part of Omarchy).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
omarchy="${OMARCHY_PATH:-/usr/share/omarchy}"
out=""
keep=0

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
}

while (( $# )); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --out) out="${2:?--out needs a directory}"; shift 2 ;;
    --keep) keep=1; shift ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

die() { echo "FAIL: $*" >&2; keep=1; exit 1; }

for tool in Hyprland hyprctl grim jq quickshell; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool not found (run this on Omarchy)"
done
[[ -d "$omarchy/shell" ]] || die "Omarchy shell not found at $omarchy/shell (set OMARCHY_PATH)"
[[ -n "${WAYLAND_DISPLAY:-}" ]] || die "Run this from a Wayland session (an Omarchy desktop)"
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || die "XDG_RUNTIME_DIR is not set"

out="${out:-${TMPDIR:-/tmp}/omarchy-multi-monitor-workspaces-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/omarchy-mm-test.XXXXXX")"
home="$tmp/home"
config="$home/.config"
state="$home/.local/state"
mkdir -p "$config/omarchy/plugins" "$config/hypr" "$state/omarchy"

# The bar only needs the rail, its shared motion code and the widget under test.
for plugin in denon.shell denon.bar denon.workspaces; do
  cp -a "$repo/plugins/$plugin" "$config/omarchy/plugins/"
done

# Keep the test bar looking like the real one when the theme state is available.
theme_state="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current"
if [[ -d "$theme_state" ]]; then
  ln -s "$theme_state" "$state/omarchy/current"
fi

cat > "$config/omarchy/shell.json" <<'JSON'
{
  "version": 1,
  "bar": {
    "id": "denon.shell",
    "position": "left",
    "transparent": false,
    "layout": {
      "left": [{ "id": "denon.workspaces" }],
      "center": [],
      "right": []
    }
  },
  "plugins": []
}
JSON

cat > "$tmp/hyprland.lua" <<'LUA'
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")
require("default.hypr.helpers")
require("default.hypr.monitor-workspaces")
require("default.hypr.looknfeel")
require("default.hypr.windows")
LUA

hypr_pid=""
shell_pid=""
cleanup() {
  local status=$?
  trap - EXIT INT TERM
  [[ -n "$shell_pid" ]] && kill "$shell_pid" 2>/dev/null || true
  [[ -n "$hypr_pid" ]] && kill "$hypr_pid" 2>/dev/null || true
  [[ -n "$shell_pid" ]] && wait "$shell_pid" 2>/dev/null || true
  [[ -n "$hypr_pid" ]] && wait "$hypr_pid" 2>/dev/null || true
  if (( keep )); then
    echo "Test files kept in: $tmp" >&2
  else
    rm -rf "$tmp"
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

snapshot_sockets() {
  find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -printf '%f\n' 2>/dev/null | sort
}

echo "Starting a nested Hyprland (a window will appear on this desktop)..."
ls "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | sort > "$tmp/hypr-dirs-before"
snapshot_sockets > "$tmp/wayland-sockets-before"
env HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" OMARCHY_PATH="$omarchy" \
  Hyprland -c "$tmp/hyprland.lua" > "$tmp/hyprland.log" 2>&1 &
hypr_pid=$!

sig=""
for _ in $(seq 1 200); do
  kill -0 "$hypr_pid" 2>/dev/null || die "nested Hyprland exited (see $tmp/hyprland.log)"
  sig="$(comm -13 <(sort "$tmp/hypr-dirs-before") <(ls "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | sort) | tail -1)"
  [[ -n "$sig" ]] && break
  sleep 0.1
done
[[ -n "$sig" ]] || die "nested Hyprland did not create an instance"

for _ in $(seq 1 100); do
  hyprctl -i "$sig" monitors -j >/dev/null 2>&1 && break
  sleep 0.1
done
hyprctl -i "$sig" monitors -j >/dev/null 2>&1 || die "nested Hyprland is not answering hyprctl"

# Hyprland's own environment still names the parent display; its new socket is
# the one that appeared after it started. That is the display its children use.
display="$(comm -13 "$tmp/wayland-sockets-before" <(snapshot_sockets) | head -1)"
[[ -n "$display" ]] || die "could not find the nested Wayland socket"

first_output="$(hyprctl -i "$sig" monitors -j | jq -r '.[0].name')"
[[ -n "$first_output" && "$first_output" != "null" ]] || die "nested Hyprland has no output"

wait_for_bar() {
  local screen="$1"
  for _ in $(seq 1 200); do
    if hyprctl -i "$sig" layers -j 2>/dev/null |
      jq -e --arg s "$screen" '.[$s] | tostring | contains("denon-shell")' >/dev/null; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

shot() {
  local screen="$1" name="$2"
  env WAYLAND_DISPLAY="$display" grim -o "$screen" "$out/$name"
}

workspace_on() {
  hyprctl -i "$sig" monitors -j |
    jq -r --arg m "$1" '.[] | select(.name == $m) | .activeWorkspace.id'
}

echo "Starting only denon.shell + denon.workspaces in the test session..."
env HOME="$home" XDG_STATE_HOME="$state" OMARCHY_PATH="$omarchy" \
  WAYLAND_DISPLAY="$display" HYPRLAND_INSTANCE_SIGNATURE="$sig" \
  QS_NO_RELOAD_POPUP=1 \
  quickshell -n -p "$omarchy/shell" > "$tmp/shell.log" 2>&1 &
shell_pid=$!

wait_for_bar "$first_output" || die "the test bar did not appear on $first_output"
# The layer exists before the shell has painted its widgets and background.
sleep 5
shot "$first_output" "1-one-monitor.png"

echo "Plugging in a virtual second monitor..."
hyprctl -i "$sig" output create headless >/dev/null

headless_output=""
for _ in $(seq 1 100); do
  headless_output="$(hyprctl -i "$sig" monitors -j |
    jq -r '.[] | select(.name | startswith("HEADLESS")) | .name' | head -1)"
  [[ -n "$headless_output" && "$headless_output" != "null" ]] && break
  sleep 0.1
done
[[ -n "$headless_output" && "$headless_output" != "null" ]] || die "virtual monitor did not appear"
wait_for_bar "$headless_output" || die "the test bar did not appear on $headless_output"

# Give the new bar, the monitor-workspaces state file and the widget bindings
# a moment to paint.
sleep 5
first_ws="$(workspace_on "$first_output")"
second_ws="$(workspace_on "$headless_output")"
[[ "$first_ws" == "1" ]] || die "expected workspace 1 on $first_output, got ${first_ws:-none}"
[[ "$second_ws" == "11" ]] || die "expected workspace 11 on $headless_output, got ${second_ws:-none}"
shot "$first_output" "2-left-monitor-ws1.png"
shot "$headless_output" "3-right-monitor-ws1.png"

echo "Switching the two monitors to different workspaces..."
hyprctl -i "$sig" dispatch "o.workspaces.focus(3, \"$headless_output\")" >/dev/null
hyprctl -i "$sig" dispatch "o.workspaces.focus(2, \"$first_output\")" >/dev/null
sleep 2

first_ws="$(workspace_on "$first_output")"
second_ws="$(workspace_on "$headless_output")"
[[ "$first_ws" == "2" ]] || die "expected workspace 2 on $first_output, got ${first_ws:-none}"
[[ "$second_ws" == "13" ]] || die "expected workspace 13 on $headless_output, got ${second_ws:-none}"
shot "$first_output" "4-left-monitor-ws2.png"
shot "$headless_output" "5-right-monitor-ws3.png"

if command -v magick >/dev/null 2>&1; then
  magick montage \
    "$out/2-left-monitor-ws1.png" "$out/3-right-monitor-ws1.png" \
    "$out/4-left-monitor-ws2.png" "$out/5-right-monitor-ws3.png" \
    -tile 2x2 -geometry +8+8 -background '#101418' "$out/contact-sheet.png"
fi

echo
echo "PASS: per-monitor workspaces are independent and both bars mark their own."
echo "Screenshots in: $out"
for file in 1-one-monitor.png 2-left-monitor-ws1.png 3-right-monitor-ws1.png \
  4-left-monitor-ws2.png 5-right-monitor-ws3.png contact-sheet.png; do
  [[ -f "$out/$file" ]] && echo "  $file"
done
echo "Your real session was not changed."
