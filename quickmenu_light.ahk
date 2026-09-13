#Requires AutoHotkey v2.0
#SingleInstance Force

; QuickMenu Light -- versi native AHK murni, tanpa WebView2/HTML sama sekali.
; Tampil instan (tidak perlu nyalain proses browser terpisah). Tampilan retro
; pixel-art dengan font raster "Terminal" (bawaan Windows, tanpa file
; tambahan) dan seleksi warna terbalik + kursor ">" ala menu game jadul.
; Fungsinya identik dengan quickmenu.ahk.

; Ganti nilai ini ke salah satu key di THEMES (di bawah) buat pindah color
; scheme -- semua palet lain tetap tersimpan, tidak perlu comment/uncomment.
ACTIVE_THEME := "amber"

; bg/fg = warna normal (background/teks); selBg/selFg = warna item terpilih
; (biasanya kebalikan dari bg/fg -- "reverse video" ala terminal jadul);
; bezel = warna window di sekeliling item (lihat myGui.BackColor di ShowMenu).
THEMES := Map(
    "game_boy", { bg: "9BBC0F", fg: "0F380F", selBg: "0F380F", selFg: "9BBC0F", bezel: "0F380F" },
    "vintage",  { bg: "F4E9D8", fg: "3E2C23", selBg: "3E2C23", selFg: "F4E9D8", bezel: "3E2C23" },
    "amber",    { bg: "1A0F00", fg: "FFB000", selBg: "FFB000", selFg: "1A0F00", bezel: "FFB000" },
    "green_term", { bg: "0A0A0A", fg: "33FF33", selBg: "33FF33", selFg: "0A0A0A", bezel: "33FF33" },
)

items := ["Close All Windows", "Open Terminal", "Open WezTerm", "Lock PC", "Sleep"]

ShowMenu()

ShowMenu() {
    global items, THEMES, ACTIVE_THEME
    theme := THEMES[ACTIVE_THEME]

    margin := 6
    itemH := 26
    w := 300
    contentW := w - margin * 2
    h := items.Length * itemH + margin * 2

    myGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "QuickMenu Light")
    ; BackColor dipakai sebagai "bezel" di sekeliling item -- Text control di
    ; bawah cuma nutup area x/y=margin..w/h-margin, sisanya nampilin ini.
    myGui.BackColor := theme.bezel
    myGui.OnEvent("Close", (*) => ExitApp())

    state := { selected: 1 }
    ctrls := []
    for i, text in items {
        y := margin + (i - 1) * itemH
        ; 0x200 = SS_CENTERIMAGE, biar teks center vertikal di baris masing-masing.
        ctrl := myGui.Add("Text", "x" margin " y" y " w" contentW " h" itemH " 0x200", text)
        ctrl.OnEvent("Click", OnItemClick)
        ctrls.Push(ctrl)
    }

    Render() {
        for i, ctrl in ctrls {
            if i = state.selected {
                ctrl.SetFont("s10 c" theme.selFg, "Terminal")
                ctrl.Opt("Background" theme.selBg)
                ctrl.Text := "> " items[i]
            } else {
                ctrl.SetFont("s10 c" theme.fg, "Terminal")
                ctrl.Opt("Background" theme.bg)
                ctrl.Text := "  " items[i]
            }
        }
    }
    Render()

    OnItemClick(ctrlObj, *) {
        for i, c in ctrls {
            if c = ctrlObj {
                state.selected := i
                Render()
                return
            }
        }
    }

    MoveSelection(delta) {
        state.selected := Mod(state.selected - 1 + delta + items.Length, items.Length) + 1
        Render()
    }

    ; Up/Down/Enter ditangkap manual (Text control bukan ListBox, tidak ada
    ; navigasi bawaan) -- discope ke window ini saja lewat HotIfWinActive
    ; supaya tidak mengganggu tombol yang sama di aplikasi lain.
    HotIfWinActive("ahk_id " myGui.Hwnd)
    Hotkey("Up", (*) => MoveSelection(-1))
    Hotkey("Down", (*) => MoveSelection(1))
    Hotkey("Enter", (*) => RunAction(myGui, items[state.selected]))
    Hotkey("NumpadEnter", (*) => RunAction(myGui, items[state.selected]))
    HotIfWinActive()

    ; Popup ala mobile/web: cuma Arrow Up/Down & Enter yang "diterima" input --
    ; tombol lain apapun (Esc, tombol Windows, dll) atau klik/pindah fokus ke
    ; luar window langsung menutup menu.
    myGui.Closing := false
    readyTick := A_TickCount
    OnMessage(0x0100, CloseOnOtherKey)   ; WM_KEYDOWN
    OnMessage(0x0006, CloseOnDeactivate) ; WM_ACTIVATE

    CloseOnOtherKey(wParam, lParam, msg, hwnd) {
        static allowed := Map(38, 1, 40, 1, 13, 1)  ; VK_UP, VK_DOWN, VK_RETURN
        if !myGui.Closing && !allowed.Has(wParam)
            ExitApp()
    }

    CloseOnDeactivate(wParam, lParam, msg, hwnd) {
        ; abaikan sesaat pas baru muncul -- hindari WM_ACTIVATE awal yang keburu
        ; nembak inactive sebelum window benar-benar settle jadi foreground.
        ; myGui.Closing juga dicek -- Destroy() di RunAction() di bawah memicu
        ; WM_ACTIVATE(inactive) balik ke sini secara reentrant; tanpa guard ini,
        ; ExitApp() kepanggil duluan SEBELUM aksi (Run/DllCall dsb) sempat jalan --
        ; gejalanya: pilih menu, langsung ke-close, tanpa aksi apapun terjadi.
        if !myGui.Closing && (wParam & 0xFFFF) = 0 && (A_TickCount - readyTick > 200)
            ExitApp()
    }

    x := (A_ScreenWidth - w) / 2
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
