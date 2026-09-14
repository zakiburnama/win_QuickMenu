# QuickMenu Light

A rofi-style quick action popup for Windows, built entirely in native AutoHotkey v2 — no external dependencies. Press a hotkey, pick an action with the arrow keys, hit Enter — done.

> A second implementation, **QuickMenu** (WebView2-based, custom HTML/CSS UI), is still under active development on the [`development`](https://github.com/zakiburnama/win_QuickMenu/tree/development) branch and isn't shipped here yet.

## How it works

- **AutoHotkey v2** creates a small, borderless, always-on-top window and draws the menu itself out of native `Text` controls — no ListBox, no browser engine, nothing else running in the background.
- Retro pixel-art look: reverse-video selection (inverted background/text) plus a `>` cursor, like an old game or terminal menu. Colors are switchable — see [Color themes](#color-themes) below.
- Up/Down/Enter are caught directly via `Hotkey`/`HotIfWinActive`, scoped to just this window.
- **Launched fresh on demand, with no persistent background process or hotkey listener.** `QuickMenuLight.exe` is launched by Lenovo Vantage's "User Defined Key" feature whenever the assigned key is pressed, shows the popup, runs the chosen action, and exits — nothing lingers in the background between presses.
- Dismisses like a mobile/web popup: **only Up/Down/Enter are "accepted" input** — any other key or clicking outside the popup closes it without running an action. Escape is the one exception: inside the Color Scheme submenu it steps back to the main menu instead of closing outright; pressed again from the main menu, it closes like everything else.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) — to run/edit [quickmenu_light.ahk](quickmenu_light.ahk) or recompile it

That's it — no runtime, no vendored library, no extra font files.

## Project structure

```
quickmenu/
├── quickmenu_light.ahk      # the whole app: GUI, theming, keyboard handling, actions
├── QuickMenuLight.exe       # compiled build (see Running it below) — a genuine single file
├── quickmenu_settings.ini   # remembers your chosen color scheme — created on first use, gitignored
└── .gitignore
```

## Actions

Defined in `RunAction()` in [quickmenu_light.ahk](quickmenu_light.ahk:204):

| Menu item | Action |
|---|---|
| Open Terminal | Launches Windows Terminal elevated (`Run("*RunAs wt.exe")`) — triggers a UAC prompt since QuickMenu Light itself runs unelevated |
| Open WezTerm | Launches WezTerm (`Run("wezterm-gui")` — not `wezterm.exe`, see [Gotchas](#gotchas) below) |
| Obsidian | Launches Obsidian via its full path under `%LOCALAPPDATA%\Programs\Obsidian\` — it's a per-user Electron install, not on PATH (see [Gotchas](#gotchas)) |
| Color Scheme | Opens the theme picker described below |
| Lock PC | Locks the workstation (`LockWorkStation`) |
| Sleep | Suspends the machine (`SetSuspendState`) |
| Close All Windows | Closes every open window (`WinClose` over `WinGetList()`) |

To add or change an item, edit the `baseItems` array and the matching `case` in `RunAction()`.

## Color themes

Selecting **Color Scheme** from the menu opens a submenu of the available themes. Pick one with Up/Down + Enter and it applies **immediately, live** — the submenu stays open so you can flip through a few before settling on one — and is written to `quickmenu_settings.ini` next to the exe, so it's remembered the next time QuickMenu Light opens. Press Escape to step back to the main menu, or Escape again (or any other key, or clicking outside) to close.

| Theme | Look |
|---|---|
| `game_boy` | Classic DMG Game Boy 4-shade green |
| `vintage` | Warm cream paper / dark brown ink |
| `amber` | Amber CRT terminal (black bg, amber text) |
| `green_term` | Phosphor-green CRT terminal |

To add a new theme, add an entry to the `THEMES` map and its name to `THEME_NAMES` at the top of [quickmenu_light.ahk](quickmenu_light.ahk:13) — it'll show up in the picker automatically. Each theme is `{ bg, fg, selBg, selFg, bezel }`: normal background/text, selected-item background/text (reverse-video, like an old terminal menu highlight), and the window's own background color (shows as a thin border/bezel around the item list) — all hex, no `#` prefix.

The font is the classic Windows raster font `Terminal`, chosen specifically because it renders as blocky pixels at small sizes with zero extra files — change the font name/size in `Render()` if you want something else.

## Running it

**As a script** (for development/testing) — requires AutoHotkey v2 installed, menu shows immediately on launch:
```
quickmenu_light.ahk
```

**As a compiled exe:**
```
Ahk2Exe.exe /in quickmenu_light.ahk /out QuickMenuLight.exe /base "<path to AutoHotkey64.exe>"
```
Note: Ahk2Exe's argument parser breaks on spaces in `/base` — use the 8.3 short path (e.g. `C:\PROGRA~1\AUTOHO~1\v2\AUTOHO~2.EXE`) if your AutoHotkey install lives under `Program Files`.

`QuickMenuLight.exe` is a genuine single file with no other dependencies — copy it anywhere.

## Wiring it to a hotkey (Lenovo Vantage)

Since the exe has no hotkey listener of its own:

1. Open **Lenovo Vantage** → **Device settings** → **Input** → **User defined key**.
2. Pick the key (e.g. F12), set the action to **Open applications and files**.
3. In the picker, only Start Menu-registered apps are browsable — the exe's real path won't show up directly. Create a shortcut to it inside `%APPDATA%\Microsoft\Windows\Start Menu\Programs\` first, then it will appear in the list.
4. Select it, save. Pressing the key now launches QuickMenu Light directly — no AHK process runs in between key presses.

## Gotchas

A few non-obvious fixes that shaped this file, in case you're extending it:

- **Centering**: get the window size from `Gui.Show(...)` with explicit `w`/`h`/`x`/`y` computed up front, not from `Show("AutoSize")` followed by `GetPos()`/`Move()` — reading the size back out after an AutoSize show and repositioning afterward isn't reliable (it renders once at the wrong spot first).
- **"Close All Windows" closing nothing**: the popup's own Gui window is itself in `WinGetList()` while it's still open. If it gets `WinClose()`d as part of the loop, that fires the `Close` event and calls `ExitApp()` immediately, cutting the loop short before any *other* window closes. Fix: call `myGui.Destroy()` first — `Destroy()`, unlike `WinClose()`, doesn't fire the `Close` event.
- **`wezterm.exe` is a console-subsystem launcher**, not the GUI app — running it directly leaves a visible console window behind `wezterm-gui.exe` that closes together with the terminal. Launch `wezterm-gui.exe` directly instead.
- **Dismiss-on-blur reentrancy**: our own `guiObj.Destroy()` (called before running the chosen action) synchronously re-triggers `WM_ACTIVATE(inactive)` on that same window, which reenters the very deactivate-handler that's supposed to close the popup on focus loss — and calls `ExitApp()` *before* the actual action (`Run()`, `DllCall()`, ...) executes. Symptom: selecting any item just closed the popup and did nothing else. Fixed with a plain guard: `myGui.Closing := true` right before our own deliberate `Destroy()`, checked by the `WM_ACTIVATE`/`WM_KEYDOWN` handlers before they call `ExitApp()`.
- **Resizing/repositioning an already-visible window with `Gui.Move(x, y, w, h)` (raw numbers) drifted further off-center each time** — needed when switching between the main menu and the Color Scheme submenu, since they have different row counts and therefore different heights. `Gui.Move()` didn't agree with the coordinates `Gui.Show("x# y# w# h#")` (string options) uses for the same window. Fix: call `Show(...)` again instead of `Move()` to reposition — pass `NoActivate` too, so re-showing an already-active window doesn't fire a spurious `WM_ACTIVATE` that the dismiss-on-blur handler above could mistake for real focus loss.
- **`Run("Obsidian.exe")` (bare name) failed silently** — unlike `wt.exe`/`wezterm-gui`, Obsidian isn't a registered PATH alias; as a per-user Electron install it lives under `%LOCALAPPDATA%\Programs\Obsidian\Obsidian.exe` and nowhere Windows' default search order looks. General rule when adding a new app to the menu: first try `where <name>.exe` in a terminal — if that finds nothing, get the exe's real path either from Task Manager (right-click the running process → *Open file location*) or its Start Menu shortcut (*More → Open file location*, or check the shortcut's *Target*), then `Run()` that full path instead of a bare name.
