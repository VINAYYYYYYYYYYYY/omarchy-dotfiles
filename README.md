<div align="center">

<img src="docs/wordmark.svg" alt="My Omarchy Dotfiles" width="700">

<p><strong>My whole Omarchy desktop, ready to install.</strong><br>
A frosted rail that wraps the screen as one surface, a quarter-circle control corner, a search-first menu, recessed windows and a fastfetch dashboard.</p>

<p>
<a href="https://omarchy.org"><img alt="Omarchy 4.0.6+ and 4.5" src="https://img.shields.io/badge/omarchy-4.0.6%2B%20%7C%204.5-7AA2F7?style=flat-square"></a>
<img alt="Hyprland 0.56+" src="https://img.shields.io/badge/hyprland-0.56%2B-1E2330?style=flat-square">
<img alt="24 plugins" src="https://img.shields.io/badge/shell%20plugins-24-1E2330?style=flat-square">
<img alt="Backs up first" src="https://img.shields.io/badge/installer-backs%20up%20first-1E2330?style=flat-square">
<a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-1E2330?style=flat-square"></a>
</p>

<img src="docs/fastfetch-claude.webp" alt="fastfetch dashboard next to Claude Code, Artzen theme" width="880">

</div>

<br>

<table align="center">
<tr>
<td align="center" width="33%"><h3>One surface</h3>Pebble Shell: the left rail and the screen frame are one frosted piece. Drawers and the menu grow out of it instead of floating on top.</td>
<td align="center" width="33%"><h3>Everything close</h3>A quarter-circle corner for brightness, volume, mic and toggles, a search-first menu on Super + Space, and drawers for Wi-Fi, sound, power and more.</td>
<td align="center" width="33%"><h3>Tuned look</h3>Glass and Depth sliders for blur and recessed windows, macOS-style motion, and a theme picker that re-themes everything in one click.</td>
</tr>
</table>

<br>

<table>
<tr>
<td width="50%"><img src="docs/fastfetch-corner.webp" alt="fastfetch dashboard and the control corner, Artzen theme"></td>
<td width="50%"><img src="docs/usage-limits.webp" alt="Claude Code and Codex usage limits drawer, Artzen theme"></td>
</tr>
<tr>
<td width="50%"><img src="docs/theme-studio.webp" alt="Theme Studio over the Arc Blueberry theme"></td>
<td width="50%"><img src="docs/menu-calendar.webp" alt="Calendar and the search-first menu, Arc Blueberry theme"></td>
</tr>
</table>

<p align="center"><sub>
Themes: Artzen and Arc Blueberry. The screenshots show my own name ("MARY") as the menu and fastfetch title;
a fresh install says OMARCHY until you <a href="#make-it-yours">set yours</a>.
The usage drawer's banked-reset button ships for Codex only.
</sub></p>

Most of it was made by describing what I wanted to Claude Code, having it show me ten or more takes, then iterating on the one I liked.

## What you get

<table>
<tr>
<td width="50%" valign="top"><strong>Pebble Shell.</strong><br>The bar is a rail down the left edge that joins the screen frame, blurred as one surface so there's no seam. Workspaces, clock, weather and tray live in it.</td>
<td width="50%" valign="top"><strong>Control corner.</strong><br>A quarter-circle drawer out of the rail's bottom corner: brightness, volume and mic as arcs, quick toggles, battery and power profile.</td>
</tr>
<tr>
<td width="50%" valign="top"><strong>Search-first menu.</strong><br>Super + Space opens "What do you need?": type to search every Omarchy action, or browse Apps, Style, Setup and the rest. It carries your own name as its title.</td>
<td width="50%" valign="top"><strong>Studio drawer.</strong><br>Glass (opacity, blur, backdrop), Depth (recessed or raised windows, tuned for light and dark themes), Tricky Tiles motion and display in one place.</td>
</tr>
<tr>
<td width="50%" valign="top"><strong>fastfetch dashboard.</strong><br>Hardware, live telemetry, system, desktop and network cards with your logo, laid out to fit the terminal's width.</td>
<td width="50%" valign="top"><strong>Usage limits.</strong><br>Claude Code and Codex weekly limits and today's tokens in the bar, read from your own signed-in CLIs.</td>
</tr>
</table>

## Everything in it

**Shell and bar**

| Plugin | What it does |
|---|---|
| `denon.shell` | Pebble Shell: the left rail and screen frame as one frosted surface. This is the bar. |
| `denon.bar` | Shared drawer and motion code the other panels use (also works as a floating pill bar on its own). |
| `denon.corner` | Quarter-circle drawer out of the rail's bottom corner: brightness, volume, mic, toggles, battery. |
| `denon.menu` | Search-first desktop menu (Super + Space). |
| `denon.studio` | One drawer for the look: Glass, Depth, Tricky Tiles and display. |
| `denon.glass` | Opacity, blur and backdrop controls. |
| `denon.recess` | Depth: recessed or raised windows, tuned separately for light and dark themes. |
| `denon.workspaces`, `denon.clock`, `denon.weather`, `denon.tray`, `denon.indicators` | Restyled bar widgets. |

**Panels and system UI**

| Plugin | What it does |
|---|---|
| `denon.audio`, `denon.network`, `denon.bluetooth`, `denon.power`, `denon.monitor`, `denon.touchpad` | Drawers for sound, Wi-Fi, Bluetooth, power, display and touchpad. |
| `denon.notifications`, `denon.osd`, `denon.polkit`, `denon.battery` | Notifications, on-screen display, password prompt and low-battery warning, restyled to match. |
| `denon.agents` | Claude Code and Codex usage limits in the bar. Uses your own signed-in CLIs. |
| `denon.dropbox` | Dropbox sync status. Only useful if you use Dropbox. |

**Installed from their own repos** by `install.sh`:

- [Hello Lock](https://github.com/denonmaryland/hello-lock): the lock screen.
- [Theme Studio](https://github.com/denonmaryland/omarchy-theme-studio): the theme and wallpaper picker.
- [Tricky Tiles](https://github.com/denonmaryland/omarchy-tricky-tiles): smoother window and workspace motion with trackpad swipes.
- [Softly](https://github.com/denonmaryland/omarchy-softly): tap a key, speak, tap again. Local Whisper dictation through [Voxtype](https://voxtype.io).

**Config**

- `hypr/`: scrolling (carousel) layout, rounded corners, macOS-style animations, blur rules for the shell, keybindings, natural scrolling, four-finger Brave tab swipes.
- `fastfetch/`: the dashboard-style fastfetch.
- `foot/`: terminal config.

## Themes

The screenshots use two themes. Their wallpapers come with them.

- **Artzen** by tahfizhabib: `omarchy theme install https://github.com/tahfizhabib/omarchy-artzen-theme`
- **Arc Blueberry** by vale-c: `omarchy theme install https://github.com/vale-c/omarchy-arc-blueberry`

## Install

You need a working Omarchy 4 install (4.0.6 or newer; 4.5 supported). The installer adds one system package if it is missing, `qt6-5compat`, which the rail draws its edges with; it asks for your password for that.

```bash
git clone https://github.com/denonmaryland/omarchy-dotfiles
cd omarchy-dotfiles
./install.sh
```

The script lists what it will change and asks once. Everything it replaces is copied to `~/.config/omarchy-dotfiles-backup/<time>/` first. It never touches `hypr/monitors.lua`.

Then log out and back in, or run `hyprctl reload && omarchy restart shell`.

### Installing with an AI agent

Paste this repository's link into your coding agent (Claude Code, Codex and so on) and ask it to install the dots. For the agent:

1. Confirm this is an Omarchy 4 system: `omarchy plugin list` should run. Stop if it doesn't.
2. Clone the repo and run the installer without the prompt:

   ```bash
   git clone https://github.com/denonmaryland/omarchy-dotfiles ~/omarchy-dotfiles
   ~/omarchy-dotfiles/install.sh --yes
   ```

3. Check that `omarchy plugin list --json` shows `denon.shell` and `hello-lock` enabled, and pass on any "could not add" lines the installer printed.
4. Tell the user where the backup folder is (the installer prints it) and how to set their name (see "Make it yours").

Don't copy files into `~/.config` by hand or edit `hypr/monitors.lua`. The installer backs up everything it replaces; hand edits skip that.

### Optional apps

These are wired up if they're installed and skipped if not:

- **Snip** for screenshots and recording (Super + Ctrl + 3/4, Alt + Print).
- **flea** as the file manager (Super + Shift + F).
- **Voxtype** for Softly dictation.
- **Brave** for the four-finger tab swipes.

### Test multi-monitor workspaces

Omarchy 4.5 gives every monitor its own workspaces 1–10, numbered in blocks
(1–10, 11–20, …). The workspaces widget follows the monitor its bar is on, so
each rail marks that monitor's current workspace even while another monitor has
focus.

`tests/multi-monitor-workspaces.sh` checks this without touching your session.
It starts a nested Hyprland in a temporary home, adds a virtual second monitor,
runs only the Pebble bar and the workspaces widget, and switches the two
monitors to different workspaces. It checks Hyprland's workspace on each
monitor, then finds the active chip in each rail's screenshot and checks that it
sits on that monitor's own workspace (a rail that follows the other monitor, or
a stale widget that shows no chip on 11–20, fails). Your theme state is copied
into the test home, not linked.

```bash
./tests/multi-monitor-workspaces.sh
```

It needs Hyprland, `grim`, `jq`, ImageMagick and Quickshell (all part of
Omarchy), prints the screenshot folder (with `chips.txt`, where it found each
chip), and leaves your real shell, config and state alone.

## Make it yours

**Name.** The menu title and the fastfetch heading read one setting. Add this to `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
{
  "root": { "label": "Pixel", "title": "PIXEL" }
}
```

Without it, both say OMARCHY. The big fastfetch logo is Omarchy's own `~/.config/omarchy/branding/about.txt`, so replace that file to change the logo.

**Bar layout.** `~/.config/omarchy/shell.json` decides which widgets sit where. Remove any you don't want (for example `denon.dropbox` or `denon.agents`).

**Look.** Open the Studio drawer in the bar to change glass, depth and motion. Its panels write `hypr/glass.lua` and `hypr/recessed_windows.lua` for you.

## Undo

Copy the files from `~/.config/omarchy-dotfiles-backup/<time>/` back into your home folder, then run `hyprctl reload && omarchy restart shell`. To drop a single plugin: `omarchy plugin disable <id>`.

## Notes

- Built and used on one laptop (Zenbook 14), on Omarchy 4.0.6 and then 4.5.0. The 4.5 per-monitor workspace indicator is tested against a virtual second monitor with `tests/multi-monitor-workspaces.sh`; multiple physical monitors are still worth a quick look.
- If a second monitor has no marked workspace after updating, the installed widget is probably stale: re-run `./install.sh` (it backs up first) and restart the shell. The pre-4.5 widget only knows workspaces 1–10, so a monitor on 11–20 shows no active chip.
- The Touchpad drawer finds your touchpad automatically. If it picks the wrong one, set `TOUCHPAD_DEVICE` to the name shown by `hyprctl devices`.
- `denon.agents` replaces Omarchy's Codex usage reader with one that fixes a read timeout. Remove `~/.local/bin/denon-agent-usage-update` to go back to the stock reader.

## Credits

- Most panels started as clones of Omarchy's built-in plugins (`omarchy plugin clone`). Omarchy is MIT licensed; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Icons in `denon.menu/icons` and `denon.tray/icons` are from [Lucide](https://lucide.dev) (ISC).
- Themes and wallpapers belong to their creators.

## License

MIT. See [LICENSE](LICENSE).
