#!/usr/bin/env bash
# Test the per-monitor workspace indicator without touching the running session.
#
# Starts a nested Hyprland in a throwaway HOME, opens a virtual second monitor
# (a headless output), runs only the Pebble bar and denon.workspaces in it, and
# captures screenshots of both monitors. It checks Hyprland's workspace per
# monitor, then finds the widget's active chip in each screenshot and checks
# that every bar marks its own monitor's workspace. The real Omarchy shell,
# config and state are never touched.
#
# Usage:
#   tests/multi-monitor-workspaces.sh              # screenshots in /tmp, clean up
#   tests/multi-monitor-workspaces.sh --out DIR    # choose where screenshots go
#   tests/multi-monitor-workspaces.sh --keep       # keep logs and temp HOME
#
# Requires: Hyprland, hyprctl, grim, jq, magick, quickshell (all part of Omarchy).
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

for tool in Hyprland hyprctl grim jq magick quickshell; do
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
# Copy it rather than link it, so nothing in the test session can write to the
# real theme state.
theme_state="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current"
if [[ -d "$theme_state" ]]; then
  cp -a "$theme_state" "$state/omarchy/current"
  # Links such as current/background are absolute and point back into the real
  # state; point them at the copy instead.
  theme_real="$(cd "$theme_state" && pwd -P)"
  while IFS= read -r -d '' link; do
    target="$(readlink "$link")"
    for prefix in "$theme_state" "$theme_real"; do
      if [[ "$target" == "$prefix"/* ]]; then
        ln -sfn "$state/omarchy/current/${target#"$prefix"/}" "$link"
        break
      fi
    done
  done < <(find "$state/omarchy/current" -type l -print0)
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
  # grim can race a just-configured output; try again before giving up.
  for _ in 1 2 3 4 5; do
    env WAYLAND_DISPLAY="$display" grim -o "$screen" "$out/$name" 2>"$tmp/grim.log" && return 0
    sleep 1
  done
  die "could not capture $screen: $(cat "$tmp/grim.log")"
}

scale_of() {
  hyprctl -i "$sig" monitors -j | jq -r --arg m "$1" '.[] | select(.name == $m) | .scale'
}

# Width in pixels of the left strip of a screenshot that holds the rail: the
# bar's own layer on that monitor (logical px) times the monitor's scale.
rail_px() {
  local screen="$1" width
  width="$(hyprctl -i "$sig" layers -j | jq -r --arg s "$screen" '
    [.[$s].levels[][] | select(.namespace == "omarchy-bar") | .w] | first // empty')"
  [[ -n "$width" && "$width" != 0 ]] || width=60
  awk -v w="$width" -v s="$(scale_of "$screen")" 'BEGIN { printf "%d", w * s + 0.5 }'
}

# The active chip is the one solid, opaque shape on the rail: the track and the
# bar are translucent over the wallpaper and the empty workspaces are small
# dots, so the chip's fill is by far the most common exact colour in the strip.
# Prints "colour count centre-y height" for the chip in a screenshot.
chip_in() {
  local file="$1" width="$2" top colour count box
  top="$(magick "$file" -crop "${width}x100000+0+0" +repage -format %c histogram:info:- |
    sort -rn | awk 'NR == 1')"
  count="$(awk -F: '{ gsub(/ /, "", $1); print $1 }' <<<"$top")"
  colour="$(grep -o -m1 '#[0-9A-Fa-f]\{6\}' <<<"$top" || true)"
  [[ -n "$colour" && -n "$count" ]] || { echo "none 0 0 0"; return; }
  box="$(magick "$file" -crop "${width}x100000+0+0" +repage \
    -fill black +opaque "$colour" -fill white -opaque "$colour" -trim -format '%h %Y' info:)"
  awk -v c="$colour" -v n="$count" -v b="$box" \
    'BEGIN { split(b, f, " "); sub(/^\+/, "", f[2]); printf "%s %d %.1f %d\n", c, n, f[2] + f[1] / 2, f[1] }'
}

# Fails unless both chips use the same fill and each is big enough to be a
# chip rather than stray wallpaper pixels.
chip_ok() {
  local label="$1" colour="$2" count="$3" height="$4" scale="$5" expect="$6"
  [[ "$colour" == "$expect" ]] ||
    die "$label: no active chip found (rail's main colour is $colour, chip is $expect)"
  awk -v n="$count" -v h="$height" -v s="$scale" 'BEGIN { exit !(n >= 300 * s * s && h >= 20 * s) }' ||
    die "$label: active chip too small (${count} px, ${height} px tall)"
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

echo "Checking each bar's active chip in the screenshots..."
left_scale="$(scale_of "$first_output")"
right_scale="$(scale_of "$headless_output")"
left_px="$(rail_px "$first_output")"
right_px="$(rail_px "$headless_output")"
read -r c2 n2 y2 h2 < <(chip_in "$out/2-left-monitor-ws1.png" "$left_px")
read -r c3 n3 y3 h3 < <(chip_in "$out/3-right-monitor-ws1.png" "$right_px")
read -r c4 n4 y4 h4 < <(chip_in "$out/4-left-monitor-ws2.png" "$left_px")
read -r c5 n5 y5 h5 < <(chip_in "$out/5-right-monitor-ws3.png" "$right_px")
{
  echo "left  $first_output scale $left_scale rail ${left_px}px"
  echo "right $headless_output scale $right_scale rail ${right_px}px"
  echo "2-left-monitor-ws1   $c2 ${n2}px centre-y $y2"
  echo "3-right-monitor-ws1  $c3 ${n3}px centre-y $y3"
  echo "4-left-monitor-ws2   $c4 ${n4}px centre-y $y4"
  echo "5-right-monitor-ws3  $c5 ${n5}px centre-y $y5"
} | tee "$out/chips.txt"

chip_ok "left bar on workspace 1" "$c2" "$n2" "$h2" "$left_scale" "$c2"
chip_ok "right bar on workspace 11" "$c3" "$n3" "$h3" "$right_scale" "$c2"
chip_ok "left bar on workspace 2" "$c4" "$n4" "$h4" "$left_scale" "$c2"
chip_ok "right bar on workspace 13" "$c5" "$n5" "$h5" "$right_scale" "$c2"

# In logical pixels: both bars start with their chip on slot 1, at the same
# height. Moving the left chip one slot (1 -> 2) gives the slot pitch; the right
# chip moved two slots (1 -> 3). A right bar that followed the focused monitor
# would mark slot 2 instead, and a pre-4.5 widget would mark nothing on 11-20.
awk -v y2="$y2" -v y3="$y3" -v y4="$y4" -v y5="$y5" -v ls="$left_scale" -v rs="$right_scale" '
  BEGIN {
    start = y3 / rs - y2 / ls
    if (start < -6 || start > 6) {
      printf "both bars should mark slot 1 at the same height; right is %+.1f px off\n", start
      exit 1
    }
    pitch = (y4 - y2) / ls
    if (pitch < 8) { printf "left chip did not move down from slot 1 to slot 2 (%.1f px)\n", pitch; exit 1 }
    slots = (y5 - y3) / rs / pitch
    if (slots < 1.6 || slots > 2.4) {
      printf "right chip moved %.2f slots, expected 2 (slot 1 -> slot 3)\n", slots
      exit 1
    }
  }' > "$tmp/chip-check.log" || die "$(cat "$tmp/chip-check.log")"

magick montage \
  "$out/2-left-monitor-ws1.png" "$out/3-right-monitor-ws1.png" \
  "$out/4-left-monitor-ws2.png" "$out/5-right-monitor-ws3.png" \
  -tile 2x2 -geometry +8+8 -background '#101418' "$out/contact-sheet.png" ||
  echo "Could not make contact-sheet.png" >&2

echo
echo "PASS: Hyprland keeps each monitor on its own workspace (1/11, then 2/13), and"
echo "      each bar's chip marks its own monitor's workspace (slot 1/1, then 2/3)."
echo "Screenshots in: $out"
for file in 1-one-monitor.png 2-left-monitor-ws1.png 3-right-monitor-ws1.png \
  4-left-monitor-ws2.png 5-right-monitor-ws3.png contact-sheet.png chips.txt; do
  [[ -f "$out/$file" ]] && echo "  $file"
done
echo "Your real session was not changed."
