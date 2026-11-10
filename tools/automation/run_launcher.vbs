' ProjectKnight Silent Launcher
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
launcherPy = scriptDir & "\launcher.py"
WshShell.Run "pythonw.exe """ & launcherPy & """", 0, False
