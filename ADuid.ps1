# ADuid.ps1
# View and Modify uid and gid information for Active Directory Users
#
# Elijah Buck 4Jan2013
#

import-module activedirectory

$idRanges = @{'Corp Users'=@(2001,6999); 
			'Corp Groups'=@(7000,13999); 
			'Satellite'=@(14000,15999)}
			
###Group Operation UI###
function groupOp {
    "Operations: "
    "  [l] List Groups with group ID set"
    "  [s] Set group ID for Group to next available"
    "  [e] exit to main menu"
    $loop = $true
    while($loop)
    {
        $op = read-host "Operation: [l]list, [s]set, [e]menu"
        switch ($op) 
        {
	    #Don't be fooled: the filter is a lexographic greater-than, not numeric
            "l" {$GwithID = Get-ADGroup -filter {gidnumber -gt 0} -properties canonicalName,gidNumber ;
                 $GwithID | sort CanonicalName| select Name,gidNumber,CanonicalName | ft -auto ;break}
	    "s" {groupMod}
            "e" {$loop = $false ;break}
            default {continue}           
        }
    }
}

###Modify a group###
function groupMod {
 $idRanges | Format-Table
 $rangeName = read-host "Enter ID range name"
 if ($idRanges[$rangeName] -ne $null) {
	#get all groupIDs and pick the next one in-range
	$idmin = $idRanges[$rangeName][0]
	$idmax = $idRanges[$rangeName][1]
	$GwithID = Get-ADGroup -filter {gidnumber -gt 0} -properties canonicalName,gidNumber
	$GwithIDinRange = $GwithID | where {$_.gidnumber -ge $idmin -and $_.gidnumber -le $idmax}
	$nextID = [int](@($GwithIDinRange | sort gidNumber)[-1]).gidNumber + 1
	if ($nextID -le $idmax) {
		#Ask for the group name to apply the ID to
		$groupName = read-host "Enter Group Name"
		read-host "Setting groupid for $groupname to $nextID. Enter/OK to confirm"
		if ((Get-ADGroup $groupname -properties gidNumber).gidNumber -ne $null) {write-host "gidNumber already set!"; Return $false}
		Set-ADGroup $groupName -Replace @{gidNumber=$nextID}
	}
	else {write-host "ID range exhausted"; Return $false}
 }
 else {write-host "Invalid ID range name"; Return $false}
}

###User Operation UI###
function userOp {
    "Operations: "
    "  [l] List Users with ID set"
    "  [s] Set users ID for user to next available"
    "  [a] List/Set user ID for all users in specified group"
    "  [e] exit to main menu"
	$loop = $true
    while($loop)
    {
        $op = read-host "Operation: [l]list, [s]set, [a]all-set [e]menu"
        switch ($op) 
        {
            "l" {$UwithID = Get-ADUser -filter {uid -gt 0} -properties canonicalName,uid,gidNumber ;
                 $UwithID | sort CanonicalName| select Name,uid,gidNumber,CanonicalName | ft -auto ;break}
	    "s" {userMod}
	    "a" {userModG}
            "e" {$loop = $false ;break}
            default {continue}           
        }
    }
}

###Modify a user###
function userMod {
 $idRanges | Format-Table
 $rangeName = read-host "Enter ID range name"
 if ($idRanges[$rangeName] -ne $null) {
	#get all ids and pick the next one in-range
	$idmin = $idRanges[$rangeName][0]
	$idmax = $idRanges[$rangeName][1]
	$UwithID = Get-ADUser -filter {uid -gt 0} -properties canonicalName,uid,gidNumber
	$UwithIDinRange = $UwithID | where {$_.uid -ge $idmin -and $_.uid -le $idmax}
	$nextID = [int] (@($UwithIDinRange | sort uid)[-1]).uid.Value + 1
	if ($nextID -le $idmax) {
		#Ask for the User to apply the ID to
		$userName = read-host "Enter User Name"
		read-host "Setting uid and gid for $userName to $nextID. Enter/OK to confirm"
		if ((Get-ADUser $userName -properties uid).uid -ne $null) {write-host "uid already set!"; Return $false}
		Set-ADUser $userName -Replace @{uid=$nextID ; gidNumber=$nextID}
	}
	else {write-host "ID range exhausted"; Return $false}
 }
 else {write-host "Invalid ID range name"; Return $false}
}

###Modify all users in a group###
function userModG {
 $idRanges | Format-Table
 $rangeName = read-host "Enter ID range name"
 if ($idRanges[$rangeName] -ne $null) {
	#get all ids and pick the next one in-range
	$idmin = $idRanges[$rangeName][0]
	$idmax = $idRanges[$rangeName][1]
	$UwithID = Get-ADUser -filter {uid -gt 0} -properties canonicalName,uid,gidNumber
	$UwithIDinRange = $UwithID | where {$_.uid -ge $idmin -and $_.uid -le $idmax}
	$nextID = [int] (@($UwithIDinRange | sort uid)[-1]).uid.Value + 1
	#Ask for the Group to enumerate users from
	$groupName = read-host "Enter Group Name"
	$usersInGroup = Get-ADGroup $groupName | Get-ADGroupMember | Where {$_.objectClass -eq "user"}
	$usersToID = $usersInGroup | Get-ADUser -properties uid | where {$_.uid.Value -eq $null}
	#Do we have enough ID space?
	if ($nextID - 1 + $usersToID.Count -le $idmax) {
		Write-Host "The following users will be modified to use IDs starting at $nextID and up"
		$usersToID | select Name | Format-Table
		read-host "Enter/OK to confirm"
		$usersToID | ForEach-Object {
			write-host "Setting $_.Name IDs to $nextID"
			Set-ADUser $_ -Replace @{uid=$nextID ; gidNumber=$nextID}
			$nextID = $nextID + 1
		}
	}
	else {write-host "ID range exhausted"; Return $false}
 }
 else {write-host "Invalid ID range name"; Return $false}
}

###Main Loop###
while($true) {
    $op = read-host "Operation: [g]group, [u]user, ctrl-c to exit"
    switch ($op)
    {
        "g" {groupOp}
        "u" {userOp}
        default {continue}
    }
}
