#Requires AutoHotkey v2.0
#SingleInstance Force

; QuickMenu Light -- versi native AHK murni, tanpa WebView2/HTML sama sekali.
; Fungsinya identik dengan quickmenu.ahk, tapi tampil instan karena tidak perlu
; nyalain proses browser terpisah tiap kali di-launch. Tampilan lebih sederhana
; (ListBox biasa), tapi jauh lebih ringan & cepat -- cocok kalau kecepatan lebih
; penting daripada tampilan custom.

items := ["Close All Windows", "Open Terminal", "Open WezTerm", "Lock PC", "Sleep"]

ShowMenu()

ShowMenu() {
    global items

    myGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "QuickMenu Light")
    myGui.BackColor := "1e1e2e"
    myGui.MarginX := 8, myGui.MarginY := 8
    myGui.SetFont("s11 cCDD6F4", "Segoe UI")
    myGui.OnEvent("Close", (*) => ExitApp())

    lb := myGui.Add("ListBox", "w300 r" items.Length " Background2A2A3C -0x800000", items)
    lb.Choose(1)

    ; Enter tidak punya event bawaan di ListBox, jadi tangkap manual --
    ; discope ke window ini saja lewat HotIfWinActive supaya tidak
    ; mengganggu Enter di aplikasi lain.
    HotIfWinActive("ahk_id " myGui.Hwnd)
    Hotkey("Enter", (*) => RunAction(myGui, lb.Text))
    Hotkey("NumpadEnter", (*) => RunAction(myGui, lb.Text))
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

    ; PENTING: hitung ukuran window dari GetPos control-nya SEBELUM Show(),
    ; lalu kasih w/h/x/y eksplisit sekaligus ke Show(). Pola "Show(AutoSize)"
    ; lalu baca GetPos/Move belakangan sempat bikin window ke-render dulu di
    ; posisi lain, jadi hasil "center"-nya salah (window sempat muncul di
    ; sembarang posisi lalu baru pindah, kadang keburu ke-capture di posisi awal).
    lb.GetPos(, , &lbW, &lbH)
    w := lbW + myGui.MarginX * 2
    h := lbH + myGui.MarginY * 2
    x := (A_ScreenWidth - w) / 2
    y := (A_ScreenHeight - h) / 2

    myGui.Show("w" w " h" h " x" x " y" y)
    lb.Focus()
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
            ; wezterm.exe (bukan wezterm-gui.exe) adalah console-subsystem launcher
            ; yang nge-spawn wezterm-gui.exe di baliknya -- muncul console kosong
            ; nempel & ikut ke-close bareng. Panggil wezterm-gui.exe langsung.
            Run("wezterm-gui")
        case "Lock PC":
            DllCall("LockWorkStation")
        case "Sleep":
            DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
    }
    ExitApp()
}
