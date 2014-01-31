#Delete empty directories created more than XXX days ago
#
#To Run: 
#     Add a call to 'removeEmpties' for each directory at the bottom of this file
#     Then execute: powershell.exe -executionpolicy remotesigned -file "c:\deletorscript\emptiesDeletor.ps1"
#
#
# Elijah Buck 7Nov2012
#

$logdir = "C:\deletorscript\emptiesDeletor"

if (-not (Test-Path $logdir)) {New-Item -Force -ItemType Directory $logdir}
$logfile = "$logdir\emptiesDeletor-$((get-date).DayOfWeek).log"
Get-Date > $logfile

function removeEmpties {
	param(
		[string]$dir,
		[int]$days
	)
	$toDel = Get-ChildItem -recurse "$dir" | 
		where {$_.PSIsContainer} | 
		where {((Get-Date) - ($_.CreationTime)).Days -gt $days} | 
		where {($_.GetFiles().Count -eq 0) -and ($_.GetDirectories().Count -eq 0)}

	$toDel | Select FullName,LastWriteTime,CreationTime | Format-Table -Auto | Out-String -Width 4096 >> $logfile
		
	if ($toDel) {$toDel | Remove-Item -Whatif}
}

###ADD DIRECTORIES TO REMOVE EMPTIES FROM HERE###
removeEmpties "C:\data\test" 180
