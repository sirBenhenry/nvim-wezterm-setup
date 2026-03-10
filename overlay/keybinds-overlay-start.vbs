' keybinds-overlay-start.vbs — Silent launcher for the keybinding overlay
' Place a shortcut to this in shell:startup to auto-start
' Or double-click to start manually

Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "pwsh.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & Replace(WScript.ScriptFullName, WScript.ScriptName, "") & "keybinds-overlay.ps1""", 0, False
