## Skript pro přidání ikon Office + Edge na plochu všem uživatelům PC. Přidat do Intune jako platform skript a spouštět jako systémový uživatel v 64bit kontextu.
$TargetFile0  = "C:\Program Files\Microsoft Office\root\Office16\excel.exe"
$TargetFile1  = "C:\Program Files\Microsoft Office\root\Office16\winword.exe"
$TargetFile2  = "C:\Program Files\Microsoft Office\root\Office16\powerpnt.exe"
$TargetFile5  = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$ShortcutFile0  = "$env:Public\Desktop\Excel.lnk"
$ShortcutFile1  = "$env:Public\Desktop\Word.lnk"
$ShortcutFile2  = "$env:Public\Desktop\PowerPoint.lnk"
$ShortcutFile5  = "$env:Public\Desktop\Edge.lnk"
$WScriptShell0 = New-Object -ComObject WScript.Shell
$WScriptShell1 = New-Object -ComObject WScript.Shell
$WScriptShell2 = New-Object -ComObject WScript.Shell
$WScriptShell5 = New-Object -ComObject WScript.Shell
$Shortcut0 = $WScriptShell0.CreateShortcut($ShortcutFile0)
$Shortcut1 = $WScriptShell1.CreateShortcut($ShortcutFile1)
$Shortcut2 = $WScriptShell2.CreateShortcut($ShortcutFile2)
$Shortcut5 = $WScriptShell5.CreateShortcut($ShortcutFile5)
$Shortcut0.TargetPath = $TargetFile0
$Shortcut1.TargetPath = $TargetFile1
$Shortcut2.TargetPath = $TargetFile2
$Shortcut5.TargetPath = $TargetFile5
$Shortcut0.Save()
$Shortcut1.Save()
$Shortcut2.Save()
$Shortcut5.Save()
