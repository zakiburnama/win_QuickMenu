# QuickMenu

A rofi-style quick action popup for Windows. Press a hotkey, pick an action with the arrow keys, hit Enter — done.

There are two implementations, sharing the same actions and the same launch-on-demand model — pick whichever fits the moment:

| | [QuickMenu](quickmenu.ahk) | [QuickMenu Light](quickmenu_light.ahk) |
|---|---|---|
| UI | WebView2 (HTML/CSS/JS, [menu.html](menu.html)) | Native AHK `Gui`/`ListBox` |
| Look | Custom dark theme, rounded corners | Plain, minimal, system-drawn |
| Startup | Noticeable delay — spins up a Chromium (`msedgewebview2.exe`) instance from scratch every launch | Instant — no separate process |
| Dependencies | `lib\` (thqby/ahk2_lib) + WebView2 Runtime | None — single-file exe |
| Customize UI via | HTML/CSS in `menu.html` | AHK `Gui` control options |

Use **QuickMenu** when you want to keep tweaking the look. Use **QuickMenu Light** when speed matters more than styling — e.g. as the one that's actually wired to your hotkey day-to-day.

## How it works

- **AutoHotkey v2** creates a small, borderless, always-on-top window and hosts the UI.
- **QuickMenu** renders the menu as plain HTML/CSS/JS via **WebView2** ([thqby/ahk2_lib](https://github.com/thqby/ahk2_lib)) instead of a native control, so it can look like a proper custom dark-themed popup. The HTML side sends the selected action back to AHK via `window.chrome.webview.postMessage(...)`.
- **QuickMenu Light** skips WebView2 entirely and uses a native `ListBox` control — arrow-key navigation comes for free from Windows, Enter/Escape are caught directly in AHK.
- Both are **launched fresh on demand, with no persistent background process or hotkey listener**. The exe is launched by Lenovo Vantage's "User Defined Key" feature whenever the assigned key is pressed, shows the popup, runs the chosen action (or does nothing on Esc), and exits — nothing lingers in the background between presses.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (to run/edit either script or recompile it)
- QuickMenu (WebView2 version) only: Microsoft Edge WebView2 Runtime (pre-installed on most modern Windows systems as a system component — it won't show up under "Installed apps", only under Settings > Apps > Installed apps > System components). QuickMenu Light has no runtime dependency beyond AutoHotkey itself.

## Project structure

```
quickmenu/
├── quickmenu.ahk           # QuickMenu — creates the GUI, hosts WebView2, handles actions
├── menu.html               # QuickMenu's popup UI (dark theme HTML/CSS, keyboard navigation)
├── QuickMenu.exe           # compiled build of quickmenu.ahk (see below)
├── quickmenu_light.ahk     # QuickMenu Light — native AHK GUI, no WebView2, handles actions
├── QuickMenuLight.exe      # compiled build of quickmenu_light.ahk (true single-file)
├── WebView2Data/           # WebView2's dedicated browser profile — created at runtime, not source
└── lib/                    # thqby/ahk2_lib, vendored (only WebView2.ahk + ComVar.ahk are actually used, only by QuickMenu)
    ├── ComVar.ahk
    └── WebView2/
        ├── WebView2.ahk
        └── 64bit/WebView2Loader.dll
```

## Actions

Both versions run the same four actions — `HandleMessage()` in [quickmenu.ahk](quickmenu.ahk:86), `RunAction()` in [quickmenu_light.ahk](quickmenu_light.ahk:41):

| Menu item | Action |
|---|---|
| Close All Windows | Closes every open window (`WinClose` over `WinGetList()`) |
| Open Terminal | Launches Windows Terminal elevated (`Run("*RunAs wt.exe")`) — triggers a UAC prompt since QuickMenu itself runs unelevated |
| Lock PC | Locks the workstation (`LockWorkStation`) |
| Sleep | Suspends the machine (`SetSuspendState`) |

To add or change an item:
- **QuickMenu**: edit the `items` array in [menu.html](menu.html) and the matching `case` in `HandleMessage()`.
- **QuickMenu Light**: edit the `items` array and the matching `case` in `RunAction()`, both in [quickmenu_light.ahk](quickmenu_light.ahk).

## Running it

**As a script** (for development/testing) — requires AutoHotkey v2 installed, menu shows immediately on launch:
```
quickmenu.ahk
quickmenu_light.ahk
```

**As a compiled exe:**
```
Ahk2Exe.exe /in quickmenu.ahk /out QuickMenu.exe /base "<path to AutoHotkey64.exe>"
Ahk2Exe.exe /in quickmenu_light.ahk /out QuickMenuLight.exe /base "<path to AutoHotkey64.exe>"
```
Note: Ahk2Exe's argument parser breaks on spaces in `/base` — use the 8.3 short path (e.g. `C:\PROGRA~1\AUTOHO~1\v2\AUTOHO~2.EXE`) if your AutoHotkey install lives under `Program Files`.

`QuickMenu.exe` must stay in the same folder as `lib\` and `menu.html` — it is **not** a single-file build. WebView2Loader.dll is loaded from `lib\WebView2\64bit\` via an explicit path at runtime, and `menu.html` is loaded via a path relative to the exe. `QuickMenuLight.exe` has no such requirement — it's a genuine single file and can be copied anywhere on its own.

## Wiring it to a hotkey (Lenovo Vantage)

Since neither exe has a hotkey listener of its own:

1. Open **Lenovo Vantage** → **Device settings** → **Input** → **User defined key**.
2. Pick the key (e.g. F12), set the action to **Open applications and files**.
3. In the picker, only Start Menu-registered apps are browsable — the exe's real path won't show up directly. Create a shortcut to it inside `%APPDATA%\Microsoft\Windows\Start Menu\Programs\` first, then it will appear in the list (both `QuickMenu` and `QuickMenu Light` shortcuts already exist there if you followed along with this project — pick whichever one you want a given key to launch).
4. Select it, save. Pressing the key now launches the app directly — no AHK process runs in between key presses.

## Notable gotchas fixed along the way

Getting WebView2 to render reliably inside an AHK v2 Gui took several non-obvious fixes — see the project memory for the full write-up if you're extending this:
- `Bounds` needs a native `WebView2.RECT()`, not a plain `{x,y,w,h}` object.
- Events are `add_<Name>(handler)`, not a Gui-style `.OnEvent(name, handler)`.
- Use `.await()`, not `.await2()`, when awaiting `CreateControllerAsync` — the latter's naive `Sleep(1)` polling is a race condition that lets the WebView2 browser process shut itself down before the controller finishes attaching.
- Keep a reference to the Controller/CoreWebView2 objects beyond local scope (e.g. attach them to the Gui object) or they can be released before content ever paints.
- `Controller.IsVisible` defaults to `false` — must be set explicitly, or the window stays empty even though navigation succeeds.
- After compiling, pass `WebView2Loader.dll`'s path explicitly — the library's own auto-detection relies on `A_LineFile`, which breaks once `#Include`d files are merged into one exe.
- `wvc.Bounds` should come from the window's real `GetClientRect` (physical pixels), not from the logical width/height passed to `Gui.Show()` — DPI scaling can otherwise leave the WebView2 content smaller than the window.
- `wvc.DefaultBackgroundColor` must be set explicitly (opaque, matching the theme) or the CSS `border-radius` corners show WebView2's default white background instead of what's behind them.

## Credits

- [thqby/ahk2_lib](https://github.com/thqby/ahk2_lib) — the WebView2 AutoHotkey v2 bindings this project is built on.
