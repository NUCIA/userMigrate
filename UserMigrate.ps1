Param($source,$destination,[switch]$help) # Define parameters to expect.

import-module ActiveDirectory # Include a goldmine of cmdlets.

# VARIABLES/OBJECTS
$Class = "User" # Define type of object being added.
$dc = "dc=steal,dc=lan" # Define domain.
$ou = "ou=Students" # Define OU.
# END VARIABLES/OBJECTS

function helper() # Help function.
{
$helpstr=@"

NAME
	UserMigrate.ps1

SYNOPSIS
	This script moves shared folders from one share to another while
	preserving Domain User security rights.

SYNTAX
	UserMigrate.ps1 -source <source directory> -destination <destination directory> [-help]
	
PARAMETERS
	-source <source directory>
		Specifies the source directory where shared folders are being transferred from.
		
	-destination <destination directory>
		Specifies the destination directory where shared folders are being transferred.
	
	-help
		Prints this help.

VERSION
	This is version 0.1.
	
AUTHOR
	Charles Spence IV
	STEAL Lab Manager
	cspence@unomaha.edu
	April 8, 2013
	
"@
$helpstr # Display help
exit
}

function userExist($chkuser) # Checks if a username exists.
{
	$out = $false # Set default return value.
 
	$Search = New-Object System.DirectoryServices.DirectorySearcher
	$Search.SearchRoot = $("LDAP://"+$dc)
	$Search.Filter = ("(objectCategory=User)")
	$Results = $Search.FindAll() # Gather all user information.
 
	foreach ($Result in $Results) # Check for username.
	{
		if( $Result.Properties.samaccountname -eq $chkuser )
		{
			$out = $true
			break
		}
	}
 
	return $out
}

function copyFiles($sDir, $dDir)
{
	"Moving files to {0}" -f $dDir
	Get-ChildItem $sDir  | %{ Copy-Item $_.Fullname $dDir -Recurse -Force}
}

function setMod($tarDir, $username) # Sets ACL to Modify for user on $tarDir
{
	$fACL = Get-ACL $tarDir
	## $fACL.SetAccessRuleProtection($True,$True) # Use for inheritance issues.
	$fRule = New-Object System.Security.AccessControl.FileSystemAccessRule `
	($username,"Modify","ContainerInherit, ObjectInherit","None","Allow")
	$fACL.AddAccessRule($fRule)
	Set-ACL $tarDir $fACL # Apply
}

clear # Clear the screen.
if($help) { helper } # Check for help parameter.
if(!$source) { Write-Error "No source directory provided!" ; exit }
if(!$destination) { Write-Error "No destination directory provided!" ; exit }

if(!$(test-path -path $source -type container)) # Check if source exists.
{
	Write-Error "Source directory does not exist!"
	exit
}

if(!$(test-path -path $destination -type container)) # Check if destination exists.
{
	Write-Error "Destination directory does not exist!"
	exit
}

$srcDirs = Get-ChildItem $source -Directory -name # Get sub-directories.

"`n##################################################"
"                 Transfer Beginning"
"##################################################"

foreach($srcDir in $srcDirs)
{
	if(userExist $srcDir)#if $srcDir exists as a user
	#{
		"`n=================================================="
		" Running on {0}" -f $srcDir
		"==================================================`n"
		$currSrc = $source + "\" + $srcDir # Assumes that there is no \.
		$currDst = $destination + "\" + $srcDir
		
		if(test-path -path $currDst -type container) # Check if destination exists.
		{
			"The directory {0} exists." -f $currDst
			$lz = $currDst + "\old_User_Dir" # Get the directory name for source.
			if(test-path -path $lz -type container) # Check if destination exists.
			{
				Write-Warning("Destination directory {0} exists." -f $lz)
			}
			else
			{
				"Destination directory {0} does not exist." -f $lz
				New-Item $lz -Type Directory | out-null # Make directory.
				copyFiles $currSrc $lz
			}
		}
		elseif(!$(test-path -path $currDst)) # Make sure there isn't a file there with that name.
		{
			"The directory {0} does not exist." -f $currDst
			New-Item $currDst -Type Directory | out-null # Make directory.
			setMod $currDst $srcDir # Set permissions on the directory.
			copyFiles $currSrc $currDst
		}
		else # Provide warning.
		{
			Write-Warning("Unable to create {0}." -f $currDst)
		}
	}
	else
	{
		Write-Warning("The directory {0} does not appear to be a user folder." -f $srcDir)
	}
}

"`n##################################################"
"               Transfer Completed!"
"##################################################`n"