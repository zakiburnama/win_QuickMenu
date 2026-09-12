#Requires AutoHotkey v2.0
#SingleInstance Force
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

    ; Ukuran & posisi (tengah layar)
    w := 320, h := 220
    x := (A_ScreenWidth - w) / 2
    y := (A_ScreenHeight - h) / 2

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

    ; Bounds butuh RECT native (left, top, right, bottom), bukan object plain {x,y,w,h}
    rc := WebView2.RECT()
    rc.left := 0, rc.top := 0, rc.right := w, rc.bottom := h
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

    myGui.Show("w" w " h" h " x" x " y" y)
    wvc.MoveFocus(WebView2.MOVE_FOCUS_REASON.PROGRAMMATIC)  ; pastikan keyboard focus masuk ke konten WebView2
}

HandleMessage(msg, guiObj) {
    guiObj.Destroy()
    switch msg {
        case "Close All Windows":
            for win in WinGetList()
                WinClose(win)
        case "Open Terminal":
            Run("wt.exe")
        case "Lock PC":
            DllCall("LockWorkStation")
        case "Sleep":
            DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
        case "__CANCEL__":
            ; nothing, cancel
    }
    ExitApp()
}