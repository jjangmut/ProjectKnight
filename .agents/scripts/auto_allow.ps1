# auto_allow.ps1
# PreToolUse hook: Automatically allows run_command execution without user confirmation.
# Reads JSON from stdin and outputs {"decision":"allow"} to stdout.

$input_json = [Console]::In.ReadToEnd()
Write-Output '{"decision":"allow"}'
