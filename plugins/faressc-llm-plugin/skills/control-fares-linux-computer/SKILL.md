---
name: control-fares-linux-computer
description: >-
  Use when controlling Fares's Linux computer via the computer-use-linux MCP —
  GUI automation (clicking, typing, keyboard shortcuts, launching apps, managing
  windows, taking screenshots) on his Asahi Linux / Hyprland machine. Read this
  BEFORE sending any keyboard shortcut, because Ctrl and Super are swapped at the
  xkb level so injected modifier chords must be inverted. Also covers the Hyprland
  keybinds, monitor/coordinate layout, and reliable computer-use workflows on this
  setup.
---

# Controlling Fares's Linux Computer (Hyprland + computer-use-linux MCP)

Desktop control runs through the `mcp__computer-use-linux__*` tools (screenshot,
click, type_text, press_key, list_windows, activate_window, get_app_state, …).
Machine: **Fedora Asahi Remix, aarch64, Hyprland (wlroots), Wayland.**

Begin a control turn with `list_windows` or `get_app_state` to see what's open.

## ⚠️ CRITICAL: Ctrl and Super are swapped (read first)

`~/.config/hypr/hyprland.conf` sets:

```
kb_options = ctrl:swap_lwin_lctl, ctrl:swap_rwin_rctl, special_letters:german_umlaute, ...
```

This swaps the **Left/Right Super (Win) keys with the Left/Right Ctrl keys at the
xkb keymap level**. Hyprland applies this keymap to _every_ keyboard — including
ydotool's virtual keyboard that computer-use injects through. So the raw evdev
modifier you inject is remapped before Hyprland and apps see it:

| You inject (`press_key`)                                        | Hyprland / apps actually receive |
| --------------------------------------------------------------- | -------------------------------- |
| `ctrl`                                                          | **Super** (Mod4)                 |
| `super` / `meta`                                                | **Control**                      |
| `alt`                                                           | Alt (unchanged)                  |
| `shift`                                                         | Shift (unchanged)                |
| plain keys, letters, `space`, `Return`, `Escape`, arrows, `Tab` | unchanged                        |

**Rule of thumb: invert Ctrl↔Super in every injected chord.**

- To send an **app shortcut `Ctrl+<k>`** (e.g. Firefox new tab, address bar, copy):
  inject `super+<k>`.
  - `super+l` → Ctrl+L (focus address bar) ✓ verified
  - `super+t` → Ctrl+T (new tab), `super+c` → Ctrl+C, `super+w` → Ctrl+W (close tab)
- To **trigger a Hyprland bind that uses `$firstMod` (= Super/Mod4)**: inject `ctrl+…`.
  - `ctrl+w` → Super+W → launches Firefox
  - `ctrl+q` → Super+Q → close window
  - `ctrl+<N>` → Super+N → switch to workspace N
- To **trigger a Hyprland bind that uses `$thirdMod` (= Control)**: inject `super+…`.
  - `super+space` → Control+Space → **wofi launcher** ✓ verified

Plain keys and `type_text` literal text are unaffected — they are always reliable.

### Collision warnings (because injected `super` becomes Control)

Some "app shortcuts" you try to send will instead hit a Hyprland Control-bind:

- `super+space` → Control+Space → opens **wofi** (not an app Ctrl+Space).
- `super+Tab` → Control+Tab → Hyprland `focuscurrentorlast` (switches window!) — you
  cannot send a plain app Ctrl+Tab this way; it gets eaten by the compositor.

> Optional permanent fix (not applied): give the ydotool virtual keyboard its own
> `device { name = <ydotool-device>; kb_options = }` block in hyprland.conf so the
> swap is NOT applied to injected input. Find the name via `hyprctl devices`. Until
> that exists, use the inversion table above.

## Hyprland keybind reference

Mod vars: `$firstMod = Mod4 (Super)`, `$secondMod = Mod1 (Alt)`, `$thirdMod = Control`.
The "inject" column already accounts for the swap.

| Action                     | Real bind                      | Inject via press_key                |
| -------------------------- | ------------------------------ | ----------------------------------- |
| App launcher (wofi)        | `Control + space`              | `super+space`                       |
| Launch terminal (kitty)    | `Super + Return`               | `ctrl+Return`                       |
| Launch Firefox             | `Super + W`                    | `ctrl+w`                            |
| Launch Thunderbird         | `Super + M`                    | `ctrl+m`                            |
| File manager (dolphin)     | `Super + E`                    | `ctrl+e`                            |
| Close active window        | `Super + Q`                    | `ctrl+q`                            |
| Toggle floating            | `Super + F`                    | `ctrl+f`                            |
| Maximize / fullscreen      | `Super + Alt + Return`         | `ctrl+alt+Return`                   |
| Unmaximize                 | `Super + Alt + Shift + Return` | `ctrl+alt+shift+Return`             |
| Lock screen (hyprlock)     | `Super + L`                    | `ctrl+l`                            |
| Logout menu (wlogout)      | `Super + Escape`               | `ctrl+Escape`                       |
| Move focus                 | `Super + arrows`               | `ctrl+<arrow>`                      |
| Switch to workspace N      | `Super + N`                    | `ctrl+<N>`                          |
| Move window to workspace N | `Super + Shift + N`            | `ctrl+shift+<N>`                    |
| Focus last window          | `Control + Tab`                | `super+Tab`                         |
| Screenshot (area)          | `Super+Alt+Ctrl + period`      | runs `~/.local/bin/screenshot_area` |

Special workspaces (scratchpads): `Super+A` magic, `Super+S` spotify, `Super+D` qpwgraph
→ inject `ctrl+a` / `ctrl+s` / `ctrl+d`.

Prefer launching apps with `hyprctl dispatch exec <app>` only if the user is fine with
shell use; otherwise use the wofi or direct-launch binds above through `press_key`.

## Display / coordinate space

- Internal panel: **eDP-1, 2560×1600 logical, scale 1.33** (`hyprctl monitors`).
- `screenshot full_screen=true` → image in the **2560×1600** desktop coordinate space.
- `screenshot pid=<pid>` (window-targeted) → raises the window, crops to it, returns
  **window-relative** coordinates (`coordinate_width`/`coordinate_height` in the result).
- Click in window-relative space with `click pid=<pid> relative=true x=… y=…`
  (same space as a window-cropped screenshot). Coordinate clicks via the uinput
  absolute pointer work; accuracy is best with `accel_profile = flat` (not currently set,
  so treat absolute coords as approximate — verify with a follow-up screenshot).

## Reliable computer-use workflows on this machine

**Screenshots:** to read UI text, capture the **full window at native resolution**
(`screenshot pid=<pid> format=jpeg quality=75`). Do NOT use `max_height`/`max_width`
to "zoom a region" — those resize the _entire_ image proportionally and make it
unreadable. There is no region-crop except window crop.

**Windows / tiling (dwindle):** `activate_window pid=<pid>` may **pull the window onto
the current workspace and tile it** beside whatever is focused (each gets half width).
Expect layout changes; re-`list_windows` after focusing. Firefox uses **vertical tabs**;
its bookmarks bar overflows (`»`) at narrow widths, so a named bookmark may be hidden —
navigate via the address bar instead.

**Launch an app (verified recipe):**

1. `press_key super+space` → wofi opens
2. `type_text "<app name>"` (e.g. `firefox`) — or it may already be the top entry
3. `press_key Return`

**Navigate Firefox to a URL or bookmark (verified recipe):**

1. `press_key super+l` (→ Ctrl+L) → address bar focused
2. `type_text "<url>"`, or `type_text "* <bookmark name>"` to filter to bookmarks only
3. `screenshot` to confirm the result, then `press_key Return` or `click` the result row

**Dismiss a dialog / doorhanger:** `press_key Escape` (plain key, reliable). Permission
doorhangers (e.g. Zoom mic/camera) can steal keyboard focus — dismiss them first.

**AT-SPI element targeting:** enabled, but an app only exposes its accessibility tree if
it was started _after_ AT-SPI was turned on. For apps already running, fall back to
screenshot + coordinate clicks, or restart the app to get its tree.

## Known reference points

- `element` bookmark → `chat.tu-berlin.de/#/home` (TU Berlin Element / Matrix).
- See also the setup guide: `~/tubcloud.tu-berlin.de/memory-bridge/guides/computer-use-linux-mcp.md`.
