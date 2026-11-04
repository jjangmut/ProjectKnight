# Run in PowerShell ON THE DEV PC if the old daily task was registered.
# This affects ONLY the known retired ProjectKnight daily task.
$Name = "JUNYPAPA_ProjectKnight_DailyDevProcess"
$Task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
if ($null -eq $Task) {
    Write-Host "[OK] Legacy scheduled task not installed."
    exit 0
}
Write-Host "[FOUND] $Name"
Unregister-ScheduledTask -TaskName $Name -Confirm:$false
$Remaining = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
if ($null -ne $Remaining) {
    Write-Error "Legacy task still exists."
    exit 1
}
Write-Host "[OK] Retired ProjectKnight task unregistered."
