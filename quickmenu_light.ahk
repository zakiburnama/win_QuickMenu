#Requires AutoHotkey v2.0
#SingleInstance Force

; QuickMenu Light -- versi native AHK murni, tanpa WebView2/HTML sama sekali.
; Tampil instan (tidak perlu nyalain proses browser terpisah). Tampilan retro
; pixel-art dengan font raster "Terminal" (bawaan Windows, tanpa file
; tambahan) dan seleksi warna terbalik + kursor ">" ala menu game jadul.
; Fungsinya identik dengan quickmenu.ahk.

; bg/fg = warna normal (background/teks); selBg/selFg = warna item terpilih
; (biasanya kebalikan dari bg/fg -- "reverse video" ala terminal jadul);
; bezel = warna window di sekeliling item (lihat myGui.BackColor di ShowMenu).
THEMES := Map(
    "game_boy", { bg: "9BBC0F", fg: "0F380F", selBg: "0F380F", selFg: "9BBC0F", bezel: "0F380F" },
    "vintage",  { bg: "F4E9D8", fg: "3E2C23", selBg: "3E2C23", selFg: "F4E9D8", bezel: "3E2C23" },
    "amber",    { bg: "1A0F00", fg: "FFB000", selBg: "FFB000", selFg: "1A0F00", bezel: "FFB000" },
    "green_term", { bg: "0A0A0A", fg: "33FF33", selBg: "33FF33", selFg: "0A0A0A", bezel: "33FF33" },
)
THEME_NAMES := ["game_boy", "vintage", "amber", "green_term"]

; Tema aktif dibaca dari file settings (dibuat/diupdate otomatis lewat menu
; "Color Scheme" di bawah) -- kalau belum ada / rusak, fallback ke "amber".
SETTINGS_FILE := A_ScriptDir "\quickmenu_settings.ini"
ACTIVE_THEME := IniRead(SETTINGS_FILE, "Settings", "Theme", "amber")
if !THEMES.Has(ACTIVE_THEME)
    ACTIVE_THEME := "amber"

baseItems := ["Close All Windows", "Open Terminal", "Open WezTerm", "Lock PC", "Sleep", "Color Scheme"]

ShowMenu()

ShowMenu() {
    global baseItems, THEMES, THEME_NAMES, ACTIVE_THEME, SETTINGS_FILE

    margin := 6
    itemH := 26
    w := 300
    x := (A_ScreenWidth - w) / 2
    contentW := w - margin * 2
    maxRows := Max(baseItems.Length, THEME_NAMES.Length)

    myGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "QuickMenu Light")
    myGui.OnEvent("Close", (*) => ExitApp())

    ; state.mode "main" = menu utama, "theme" = submenu pilih color scheme.
    ; state.theme (bukan variabel lokal biasa) supaya bisa diganti dari dalam
    ; OnEnter() saat pilih tema baru -- closure AHK aman nulis property object,
    ; tapi tidak dijamin aman nulis-ulang variabel lokal biasa dari nested func.
    ; ctrls dibuat sebanyak baris TERBANYAK dari kedua daftar, lalu baris yang
    ; tidak dipakai di-nonaktifkan (Visible=false) tergantung mode aktif.
    state := { selected: 1, mode: "main", theme: THEMES[ACTIVE_THEME] }
    ; BackColor dipakai sebagai "bezel" di sekeliling item -- Text control di
    ; bawah cuma nutup area x/y=margin..w/h-margin, sisanya nampilin ini.
    myGui.BackColor := state.theme.bezel
    ctrls := []
    loop maxRows {
        y := margin + (A_Index - 1) * itemH
        ; 0x200 = SS_CENTERIMAGE, biar teks center vertikal di baris masing-masing.
        ctrl := myGui.Add("Text", "x" margin " y" y " w" contentW " h" itemH " 0x200")
        ctrl.OnEvent("Click", OnItemClick)
        ctrls.Push(ctrl)
    }

    CurrentList() {
        if state.mode = "main"
            return baseItems
        list := []
        for name in THEME_NAMES
            list.Push(name = ACTIVE_THEME ? name " (current)" : name)
        return list
    }

    Render() {
        list := CurrentList()
        for i, ctrl in ctrls {
            if i > list.Length {
                ctrl.Visible := false
                continue
            }
            ctrl.Visible := true
            if i = state.selected {
                ctrl.SetFont("s10 c" state.theme.selFg, "Terminal")
                ctrl.Opt("Background" state.theme.selBg)
                ctrl.Text := "> " list[i]
            } else {
                ctrl.SetFont("s10 c" state.theme.fg, "Terminal")
                ctrl.Opt("Background" state.theme.bg)
                ctrl.Text := "  " list[i]
            }
        }
    }

    ; Ganti mode (main <-> theme) berarti jumlah baris ikut berubah, jadi
    ; window di-resize ulang (tinggi menyesuaikan + tetap center) sebelum render.
    ; PENTING: pakai Show() lagi (bukan Move()) -- Move() dengan angka mentah
    ; ternyata tidak konsisten dengan koordinat yang dipakai Show("x# y#..."),
    ; bikin window malah geser (kemungkinan mismatch DPI antara method call
    ; langsung vs string options, sama seperti kasus di versi WebView2).
    ; NoActivate supaya reposisi ini tidak memicu WM_ACTIVATE yang bisa
    ; disalahartikan CloseOnDeactivate sebagai window kehilangan fokus.
    SwitchMode(newMode) {
        state.mode := newMode
        state.selected := 1
        newH := CurrentList().Length * itemH + margin * 2
        newY := (A_ScreenHeight - newH) / 2
        myGui.Show("w" w " h" newH " x" x " y" newY " NoActivate")
        Render()
    }

    OnItemClick(ctrlObj, *) {
        for i, c in ctrls {
            if c = ctrlObj && ctrlObj.Visible {
                state.selected := i
                Render()
                return
            }
        }
    }

    MoveSelection(delta) {
        len := CurrentList().Length
        state.selected := Mod(state.selected - 1 + delta + len, len) + 1
        Render()
    }

    OnEnter() {
        global ACTIVE_THEME
        choice := CurrentList()[state.selected]
        if state.mode = "main" {
            if choice = "Color Scheme"
                SwitchMode("theme")
            else
                RunAction(myGui, choice)
        } else {
            ; Terapkan tema langsung (live) & tetap di submenu -- biar bisa
            ; coba-coba beberapa tema dulu sebelum keluar, bukan langsung exit.
            ; buang label " (current)" -- itu cuma penanda visual, bukan nama tema asli.
            chosen := StrReplace(choice, " (current)", "")
            IniWrite(chosen, SETTINGS_FILE, "Settings", "Theme")
            ACTIVE_THEME := chosen
            state.theme := THEMES[chosen]
            myGui.BackColor := state.theme.bezel
            Render()
        }
    }

    ; Up/Down/Enter ditangkap manual (Text control bukan ListBox, tidak ada
    ; navigasi bawaan) -- discope ke window ini saja lewat HotIfWinActive
    ; supaya tidak mengganggu tombol yang sama di aplikasi lain.
    HotIfWinActive("ahk_id " myGui.Hwnd)
    Hotkey("Up", (*) => MoveSelection(-1))
    Hotkey("Down", (*) => MoveSelection(1))
    Hotkey("Enter", (*) => OnEnter())
    Hotkey("NumpadEnter", (*) => OnEnter())
    HotIfWinActive()

    ; Popup ala mobile/web: cuma Arrow Up/Down & Enter yang "diterima" input --
    ; tombol lain apapun (Esc, tombol Windows, dll) atau klik/pindah fokus ke
    ; luar window langsung menutup menu. Berlaku di mode manapun (main/theme).
    myGui.Closing := false
    readyTick := A_TickCount
    OnMessage(0x0100, CloseOnOtherKey)   ; WM_KEYDOWN
    OnMessage(0x0006, CloseOnDeactivate) ; WM_ACTIVATE

    CloseOnOtherKey(wParam, lParam, msg, hwnd) {
        static allowed := Map(38, 1, 40, 1, 13, 1)  ; VK_UP, VK_DOWN, VK_RETURN
        if myGui.Closing || allowed.Has(wParam)
            return
        ; Escape (27) di submenu tema = mundur satu halaman ke menu utama dulu,
        ; bukan langsung nutup. Escape di menu utama, atau tombol lain apapun
        ; di mode manapun, tetap langsung nutup seperti biasa.
        if wParam = 27 && state.mode = "theme" {
            SwitchMode("main")
            return
        }
        ExitApp()
    }

    CloseOnDeactivate(wParam, lParam, msg, hwnd) {
        ; abaikan sesaat pas baru muncul -- hindari WM_ACTIVATE awal yang keburu
        ; nembak inactive sebelum window benar-benar settle jadi foreground.
        ; myGui.Closing juga dicek -- Destroy() di RunAction()/OnEnter() memicu
        ; WM_ACTIVATE(inactive) balik ke sini secara reentrant; tanpa guard ini,
        ; ExitApp() kepanggil duluan SEBELUM aksi (Run/DllCall/IniWrite dsb) sempat
        ; jalan -- gejalanya: pilih menu, langsung ke-close, tanpa aksi apapun terjadi.
        if !myGui.Closing && (wParam & 0xFFFF) = 0 && (A_TickCount - readyTick > 200)
            ExitApp()
    }

    Render()
    h := CurrentList().Length * itemH + margin * 2
    y := (A_ScreenHeight - h) / 2
    myGui.Show("w" w " h" h " x" x " y" y)
}

RunAction(myGui, item) {
    ; PENTING: destroy window kita SENDIRI dulu sebelum "Close All Windows"
    ; jalan. WinClose() sendiri (bukan Destroy()) di bawah triggers event
    ; "Close" yang kita daftarkan di atas -- kalau window kita masih ada saat
    ; WinGetList() dipanggil, dia bisa ikut ke-WinClose duluan, memicu
    ; ExitApp() instan, dan motong loop sebelum sempat nutup window lain.
    myGui.Closing := true
    myGui.Destroy()
    switch item {
        case "Close All Windows":
            for win in WinGetList()
                WinClose(win)
        case "Open Terminal":
            Run("*RunAs wt.exe")
        case "Open WezTerm":
            Run("wezterm-gui")
        case "Lock PC":
            DllCall("LockWorkStation")
        case "Sleep":
            DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
    }
    ExitApp()
}
