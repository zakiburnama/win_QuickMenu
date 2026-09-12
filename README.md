# QuickMenu

A rofi-style quick action popup for Windows, built with AutoHotkey v2 and WebView2. Press a hotkey, pick an action with the arrow keys, hit Enter — done.

## How it works

- **AutoHotkey v2** creates a small, borderless, always-on-top window and hosts the UI.
- **WebView2** ([thqby/ahk2_lib](https://github.com/thqby/ahk2_lib)) renders the menu itself as plain HTML/CSS/JS ([menu.html](menu.html)) instead of a native ListBox, so it looks like a proper dark-themed popup.
- The HTML side sends the selected action back to AHK via `window.chrome.webview.postMessage(...)`, and AHK runs the matching system action.
- There is **no persistent background process or hotkey listener**. `QuickMenu.exe` is launched fresh on demand by Lenovo Vantage's "User Defined Key" feature whenever F12 is pressed, shows the popup, runs the chosen action (or does nothing on Esc), and exits — nothing lingers in the background between presses.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (to run/edit [quickmenu.ahk](quickmenu.ahk) or recompile it)
- Microsoft Edge WebView2 Runtime (pre-installed on most modern Windows systems as a system component — it won't show up under "Installed apps", only under Settings > Apps > Installed apps > System components)

## Project structure

```
quickmenu/
├── quickmenu.ahk      # main script — creates the GUI, hosts WebView2, handles actions
├── menu.html          # the popup UI itself (dark theme, keyboard navigation)
├── QuickMenu.exe       # compiled build (see below)
├── WebView2Data/       # WebView2's dedicated browser profile — created at runtime, not source
└── lib/                # thqby/ahk2_lib, vendored (only WebView2.ahk + ComVar.ahk are actually used)
    ├── ComVar.ahk
    └── WebView2/
        ├── WebView2.ahk
        └── 64bit/WebView2Loader.dll
```

## Actions

Defined in `HandleMessage()` in [quickmenu.ahk](quickmenu.ahk:67):

| Menu item | Action |
|---|---|
| Close All Windows | Closes every open window (`WinClose` over `WinGetList()`) |
| Open Terminal | Launches Windows Terminal (`wt.exe`) |
| Lock PC | Locks the workstation (`LockWorkStation`) |
| Sleep | Suspends the machine (`SetSuspendState`) |

To add or change an item, edit both the `items` array in [menu.html](menu.html) and the matching `case` in `HandleMessage()`.

## Running it

**As a script** (for development/testing):
```
quickmenu.ahk
```
Requires AutoHotkey v2 installed. The menu shows immediately on launch.

**As a compiled exe:**
```
Ahk2Exe.exe /in quickmenu.ahk /out QuickMenu.exe /base "<path to AutoHotkey64.exe>"
```
Note: Ahk2Exe's argument parser breaks on spaces in `/base` — use the 8.3 short path (e.g. `C:\PROGRA~1\AUTOHO~1\v2\AUTOHO~2.EXE`) if your AutoHotkey install lives under `Program Files`.

`QuickMenu.exe` must stay in the same folder as `lib\` and `menu.html` — it is **not** a single-file build. WebView2Loader.dll is loaded from `lib\WebView2\64bit\` via an explicit path at runtime, and `menu.html` is loaded via a path relative to the exe.

## Wiring it to a hotkey (Lenovo Vantage)

Since the exe has no hotkey listener of its own:

1. Open **Lenovo Vantage** → **Device settings** → **Input** → **User defined key**.
2. Pick the key (e.g. F12), set the action to **Open applications and files**.
3. In the picker, only Start Menu-registered apps are browsable — `QuickMenu.exe`'s real path won't show up directly. Create a shortcut to it inside `%APPDATA%\Microsoft\Windows\Start Menu\Programs\` first, then it will appear in the list.
4. Select it, save. Pressing the key now launches QuickMenu directly — no AHK process runs in between key presses.

## Notable gotchas fixed along the way

Getting WebView2 to render reliably inside an AHK v2 Gui took several non-obvious fixes — see the project memory for the full write-up if you're extending this:
- `Bounds` needs a native `WebView2.RECT()`, not a plain `{x,y,w,h}` object.
- Events are `add_<Name>(handler)`, not a Gui-style `.OnEvent(name, handler)`.
- Use `.await()`, not `.await2()`, when awaiting `CreateControllerAsync` — the latter's naive `Sleep(1)` polling is a race condition that lets the WebView2 browser process shut itself down before the controller finishes attaching.
- Keep a reference to the Controller/CoreWebView2 objects beyond local scope (e.g. attach them to the Gui object) or they can be released before content ever paints.
- `Controller.IsVisible` defaults to `false` — must be set explicitly, or the window stays empty even though navigation succeeds.
- After compiling, pass `WebView2Loader.dll`'s path explicitly — the library's own auto-detection relies on `A_LineFile`, which breaks once `#Include`d files are merged into one exe.

## Credits

- [thqby/ahk2_lib](https://github.com/thqby/ahk2_lib) — the WebView2 AutoHotkey v2 bindings this project is built on.
