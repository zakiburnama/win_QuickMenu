#Requires AutoHotkey v2.0
#SingleInstance Force
; Harus di-set sebelum window apapun dibuat. WebView2 selalu Per-Monitor-V2 DPI
; aware secara internal; kalau host AHK-nya tidak, Windows men-scale window AHK
; secara virtual sementara WebView2 tetap pakai pixel fisik untuk Bounds --
; hasilnya box konten (WebView2) jadi lebih kecil dari window (AHK).
DllCall("SetProcessDpiAwarenessContext", "ptr", -4, "int")  ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
#Include <WebView2\WebView2>

; Tidak pakai hotkey sendiri -- QuickMenu.exe akan di-launch langsung oleh
; Lenovo Vantage (User Defined Key F12 -> Open applications and files) setiap
; kali F12 ditekan, jadi cukup tampilkan menu begitu proses ini start, lalu
; exit bersih setelah aksi dijalankan. Tidak ada proses AHK yang nongkrong
; nunggu hotkey di background.
ShowMenu()

ShowMenu() {
    myGui := Gui("+AlwaysOnTop -Caption", "QuickMenu")
    myGui.BackColor := "1e1e2e"
    myGui.OnEvent("Close", (*) => ExitApp())

    ; Ukuran & posisi (tengah layar). Show() duluan sebelum bikin WebView2
    ; controller (sama seperti contoh resmi WebView2.create()) supaya window
    ; sudah punya ukuran fisik yang pasti sebelum kita baca GetClientRect di bawah.
    w := 320, h := 220
    x := (A_ScreenWidth - w) / 2
    y := (A_ScreenHeight - h) / 2
    myGui.Show("w" w " h" h " x" x " y" y)

    ; dataDir eksplisit: kalau dikosongkan, lib ini default pakai folder profil Edge ASLI
    ; (...\Local\Microsoft\Edge\User Data) -- bisa lambat/konflik. Pakai folder khusus & kosong.
    dataDir := A_ScriptDir "\WebView2Data"
    ; PENTING: pakai .await() (bukan .await2()) -- .await2() cuma Sleep(1) polling status,
    ; sedangkan .await() betul-betul memompa message queue Windows (PeekMessage/MsgWaitForMultipleObjects).
    ; WebView2 butuh message pump yang presisi buat callback COM/STA async-nya; .await2() rentan
    ; race condition yang bikin browser process WebView2 keburu shutdown sendiri sebelum controller
    ; sempat terpasang ke window (root cause dari "msedgewebview2.exe start lalu langsung hilang").
    ; PENTING: WebView2Loader.dll harus dicari via path eksplisit, bukan default
    ; lib (yang pakai A_LineFile). Setelah di-compile ke exe, semua kode #Include
    ; digabung jadi satu sehingga A_LineFile ikut berubah jadi path exe itu sendiri,
    ; bukan lagi lib\WebView2\ -- otomatis-deteksi DLL di lib jadi salah lokasi
    ; ("Failed to load DLL: WebView2Loader.dll"). Exe & folder lib\ harus tetap
    ; satu folder yang sama (lihat catatan di komentar deployment paling bawah).
    dllPath := A_ScriptDir "\lib\WebView2\" (A_PtrSize * 8) "bit\WebView2Loader.dll"
    wvc := WebView2.CreateControllerAsync(myGui.Hwnd, 0, dataDir, '', dllPath).await()
    ; PENTING: tahan referensi controller & CoreWebView2 dengan nempelkannya ke myGui.
    ; Kalau cuma variabel lokal, AHK bisa release/garbage-collect objek COM-nya
    ; sebelum benar-benar terpasang -- ini penyebab umum window WebView2 tampil
    ; kosong (kotak ada, konten tidak pernah render) yang dilaporkan di forum AHK.
    myGui.WVController := wvc

    ; WebView2 default background-nya PUTIH -- karena #container di menu.html
    ; punya border-radius, area di luar rounded-corner (yang di-"potong" CSS)
    ; nembus ke background asli WebView2 ini, bukan ke BackColor Gui. Samakan
    ; dengan warna tema (#1e1e2e, opaque) supaya rounded corner tidak putih.
    ; Format: uint dari struct {A,R,G,B} - little-endian jadi A|(R<<8)|(G<<16)|(B<<24).
    wvc.DefaultBackgroundColor := 0x2E1E1EFF

    ; Bounds butuh RECT native (left, top, right, bottom), bukan object plain {x,y,w,h}.
    ; PENTING: ambil ukuran client area SEBENARNYA (physical pixel) via GetClientRect,
    ; bukan pakai w/h logical kita sendiri -- kalau ada DPI scaling, window AHK bisa
    ; jadi lebih besar secara fisik daripada w/h yang kita minta, sementara WebView2
    ; selalu pakai physical pixel buat Bounds-nya. Mismatch ini yang bikin box WebView2
    ; lebih kecil dari window (ada area kosong di kanan/bawah).
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "ptr", myGui.Hwnd, "ptr", rc)
    wvc.Bounds := rc

    ; PENTING: Controller tidak otomatis visible -- default-nya IsVisible=0,
    ; jadi konten sudah ter-load & ter-render secara internal tapi tidak pernah
    ; digambar ke layar sampai ini di-set true (ini penyebab "box kosong").
    wvc.IsVisible := true

    wv := wvc.CoreWebView2
    myGui.WVCore := wv

    htmlPath := A_ScriptDir "\menu.html"
    wv.Navigate("file:///" StrReplace(htmlPath, "\", "/"))

    ; Terima pesan dari JS (postMessage) -- lib ini pakai add_<EventName>, bukan .OnEvent()
    wv.add_WebMessageReceived((ctrl, args) => HandleMessage(args.TryGetWebMessageAsString(), myGui))

    wvc.MoveFocus(WebView2.MOVE_FOCUS_REASON.PROGRAMMATIC)  ; pastikan keyboard focus masuk ke konten WebView2
}

HandleMessage(msg, guiObj) {
    guiObj.Destroy()
    switch msg {
        case "Close All Windows":
            for win in WinGetList()
                WinClose(win)
        case "Open Terminal":
            ; *RunAs -- munculkan UAC prompt karena QuickMenu.exe sendiri jalan
            ; tidak elevated, jadi elevasi cuma bisa lewat dialog itu.
            Run("*RunAs wt.exe")
        case "Lock PC":
            DllCall("LockWorkStation")
        case "Sleep":
            DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
        case "__CANCEL__":
            ; nothing, cancel
    }
    ExitApp()
}