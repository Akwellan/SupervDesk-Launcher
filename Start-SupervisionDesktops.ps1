Start-Sleep -Seconds 60

$wshell = New-Object -ComObject WScript.Shell

# ============================================================
# Gestion des bureaux virtuels
# ============================================================

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Threading;

public class VirtualDesktopKeys
{
    [DllImport("user32.dll")]
    static extern void keybd_event(
        byte bVk,
        byte bScan,
        uint dwFlags,
        UIntPtr dwExtraInfo
    );

    const uint KEYEVENTF_KEYUP = 0x0002;

    const byte VK_CONTROL = 0x11;
    const byte VK_LWIN    = 0x5B;
    const byte VK_LEFT    = 0x25;
    const byte VK_RIGHT   = 0x27;

    static void PressCombo(byte arrow)
    {
        keybd_event(VK_CONTROL, 0, 0, UIntPtr.Zero);
        keybd_event(VK_LWIN,    0, 0, UIntPtr.Zero);
        keybd_event(arrow,      0, 0, UIntPtr.Zero);

        Thread.Sleep(100);

        keybd_event(arrow,      0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        keybd_event(VK_LWIN,    0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    public static void Left()
    {
        PressCombo(VK_LEFT);
    }

    public static void Right()
    {
        PressCombo(VK_RIGHT);
    }
}
"@

# ============================================================
# ATTENTE DU DÉMARRAGE WINDOWS
# ============================================================

Start-Sleep -Seconds 5


# ============================================================
# RETOUR FORCÉ SUR LE BUREAU 1
# ============================================================
# On fait plusieurs Ctrl + Win + Gauche.
# Si on est déjà sur le bureau 1, ça ne fait rien.
# Ça permet de revenir au bureau le plus à gauche.

1..5 | ForEach-Object {
    [VirtualDesktopKeys]::Left()
    Start-Sleep -Milliseconds 300
}

Start-Sleep -Seconds 1


# ============================================================
# BUREAU 1 - SUPERVISION
# ============================================================

Start-Process "msedge.exe" '--new-window "https://supervision.icare-lims.local/cmk/check_mk/login.py?_origtarget=/cmk/check_mk/dashboard.py?name=dash_latence_RDS&_username=supervision&_password=A_METTRE&_login=1"'

Start-Sleep -Seconds 4

$wshell.AppActivate("Microsoft Edge")
Start-Sleep -Milliseconds 500
$wshell.SendKeys("{F11}")

Start-Sleep -Seconds 2


# ============================================================
# PASSAGE AU BUREAU 2 EXISTANT
# ============================================================

[VirtualDesktopKeys]::Right()

Start-Sleep -Seconds 2


# ============================================================
# BUREAU 2 - DEUXIÈME PAGE
# ============================================================

Start-Process "msedge.exe" '--new-window "https://supervision.icare-lims.local/cmk/check_mk/login.py?_origtarget=/cmk/check_mk/dashboard.py&_username=supervision&_password=A_METTRE&_login=1"'

Start-Sleep -Seconds 4

$wshell.AppActivate("Microsoft Edge")
Start-Sleep -Milliseconds 500
$wshell.SendKeys("{F11}")