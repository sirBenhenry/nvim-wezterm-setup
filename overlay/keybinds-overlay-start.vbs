' keybinds-overlay-start.vbs -- Silent launcher for the keybinding overlay
' Place a shortcut to this in shell:startup to auto-start
' Or double-click to start manually

Set WshShell = CreateObject("WScript.Shell")
Dim scriptDir
scriptDir = Replace(WScript.ScriptFullName, WScript.ScriptName, "")

' Try PowerShell 7 (pwsh.exe) first, fall back to PowerShell 5.1 (powershell.exe)
On Error Resume Next
WshShell.Run "pwsh.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & scriptDir & "keybinds-overlay.ps1""", 0, False
If Err.Number <> 0 Then
    Err.Clear
    WshShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & scriptDir & "keybinds-overlay.ps1""", 0, False
End If
On Error GoTo 0
