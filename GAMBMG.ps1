param (
    [string]$group,
    [string]$typeName,
    [string]$owner,
    [string]$mailPref,
    [string]$dept,
    [string]$Force,
    [string]$TestMode
)

# Assign internal booleans

    switch -Wildcard ([string]$Force).ToLower() {
        "y*" { $ShouldForce = $true }
        "n*" { $ShouldForce = $false }
        default { $ShouldForce = $false }
    }

    switch -Wildcard ([string]$TestMode).ToLower() {
        "y*" { $ShouldTestMode = $true }
        "n*" { $ShouldTestMode = $false }
        default { $ShouldTestMode = $false }
    }

# If the user calls "GAMBMG HELP" return some helpful stuff

if (($group -eq "help") -and 
    -not $typeName -and
    -not $owner -and
    -not $mailPref -and
    -not $dept -and
    -not $Force -and
    -not $TestMode) {
    
    Write-Host @"
gambmg usage:
    -group <groupName>        : The group email prefix (without domain)
    -typeName <alias|announce|discussion> : Type of group
    -owner <ownerEmail>       : Owner email prefix (without domain)
    -mailPref <allmail|nomail>: Whether owner receives mail
    -dept <department>        : Department name
    -Force <y/n>              : Skip confirmation prompt (default no)
    -TestMode <y/n>             : Dry run mode, no changes made (default no)

If you run gambmg with no parameters, you will be prompted interactively.
"@
    exit 0
}

# If the user calls "GAMBMG ABOUT" introduce yourself

if (($group -eq "about") -and 
    -not $typeName -and
    -not $owner -and
    -not $mailPref -and
    -not $dept -and
    -not $Force -and
    -not $TestMode) {
    
    Write-Host @"
GAMBMG_V2 for Windows Powershell - 6/3/2025
	This powershell script is designed to automate the creation 
	of Google Groups for the Burning Man Project. 
	
	GAM version 4.65.82 or greater, though GAMADV-X is preferred.
		https://github.com/taers232c/GAMADV-X
	Template Groups are required to provide settings to be copied to the new group.
	
Author:		DFtI for The Burning Man Project User Success department
Email:		devin@burningman.org
		Shamelessly stolen from Eric Haugen's Original bash shell script of the same name.
		
Updates:
	7/2/25 	Added additional add-user loop after group creation.
		Added currated group summary after group creation, and if the group address already exists.
	
"@
    exit 0
}



$gamPath = "C:\GAMADV-XTD3"
$ErrorActionPreference = "Stop"

function Test-Exists {
    param([string]$email)
    try {
        $output = & "$gamPath\gam.exe" whatis $email 2>&1
        return -not ($output -match "Service not applicable|Entity does not exist")
    } catch {
        return $false
    }
}

function Show-GroupSummary {
    param([string]$groupName)

    $raw = & "$gamPath\gam.exe" whatis $groupName 2>&1
    $includeBlock = $false
    $aliases = @()
    $members = @()

    Write-Host "`n=== GROUP SUMMARY ===" -ForegroundColor Cyan

    foreach ($line in $raw) {
        $trimmed = $line.Trim()

        # Always include these lines
        if ($trimmed -match "^Group: " -or
            $trimmed -match "^Total Members in Group:") {
            Write-Host $trimmed
        }

        # Select keys you want to show from 'Group Settings'
        elseif ($trimmed -match "^(id|name|description|customFooterText):") {
            Write-Host "    $trimmed"
        }

        # Print section headers
        elseif ($trimmed -match "^Group Settings:$") {
            Write-Host "  Group Settings:"
        }
        elseif ($trimmed -match "^Non-Editable Aliases:") {
            Write-Host "  Non-Editable Aliases: $($trimmed -replace '^Non-Editable Aliases:', '')"
            $includeBlock = "aliases"
        }
        elseif ($trimmed -match "^Members:") {
            Write-Host "  Members: $($trimmed -replace '^Members:', '')"
            $includeBlock = "members"
        }

        # Print alias and member lines (indented beneath respective headers; no
        #   data is collected)
        elseif ($includeBlock -eq "aliases" -and $trimmed -match "^alias: ") {
            Write-Host "    $trimmed"
        }
        elseif ($includeBlock -eq "members" -and $trimmed -match "^(owner|manager|member): ") {
            Write-Host "    $trimmed"
        }

        # Stop including extra lines once the section ends
        elseif ($trimmed -eq "") {
            $includeBlock = $false
        }
    }

    Write-Host "======================" -ForegroundColor Cyan
}

function Get-Template {
    param([string]$type)
    switch -Wildcard ($type.ToLower()) {
        { $_ -like "a*" -and $_ -notlike "an*" } { return @("aliastemplate@burningman.org", "alias") }
        { $_ -like "an*" }                       { return @("announcetemplate@burningman.org", "announce") }
        { $_ -like "d*" }                        { return @("discussiontemplate@burningman.org", "discussion") }
        default                                  { return $null }
    }
}

# Prompt user for missing args
if (-not $group) {
    do {
        $group = Read-Host "Enter the group email"
        if ($group -match "@") { $group = $group.Split("@")[0] }

        if (Test-Exists $group) {
            Write-Host "Group already exists. Try a new address." -ForegroundColor Yellow
			Show-GroupSummary "$group@burningman.org"
            $group = $null
        }
    } while (-not $group)
} else {
    if ($group -match "@") { $group = $group.Split("@")[0] }
	
	if (Test-Exists $group) {
            Write-Host "CRITICAL ERROR: Group already exists." -ForegroundColor Red
            exit 1
        }
}

if (-not $typeName) {
    do {
        $typeInput = Read-Host "Enter the group type (alias, discussion, announce)"
        $templateResult = Get-Template $typeInput
        if ($templateResult) {
            $template  = $templateResult[0]
            $typeName  = $templateResult[1]
        } else {
            Write-Host "Please enter a valid group type." -ForegroundColor Yellow
        }
    } while (-not $templateResult)
} else {
    $templateResult = Get-Template $typeName
    if ($templateResult) {
        $template  = $templateResult[0]
        $typeName  = $templateResult[1]
    } else {
        Write-Host "CRITICAL ERROR: Invalid group type passed in args." -ForegroundColor Red
        exit 1
    }
}

if (-not $owner) {
    do {
        $owner = Read-Host "Enter the owner email"
        if ($owner -match "@") { $owner = $owner.Split("@")[0] }

        if (-not (Test-Exists $owner)) {
            Write-Host "Owner not found. Try again." -ForegroundColor Yellow
            $owner = $null
        }
    } while (-not $owner)
} else {
    if ($owner -match "@") { $owner = $owner.Split("@")[0] }

    if (-not (Test-Exists $owner)) {
        Write-Host "CRITICAL ERROR: Owner email provided does not exist." -ForegroundColor Red
        exit 1
    }
}

if (-not $mailPref) {
    do {
        $response = Read-Host "Should the owner receive mail from the group? [y/n]"
        switch -Wildcard ($response.ToLower()) {
            "y*" { $mailPref = "allmail" }
            "n*" { $mailPref = "nomail" }
            default {
                Write-Host "Please enter 'y' or 'n'." -ForegroundColor Yellow
            }
        }
    } while (-not $mailPref)
}

if (-not $dept) {
    $dept = Read-Host "Enter the department"
}

# Preview
$desc = "This Group is managed by Burning Man for $dept"
Write-Host "`n=== GROUP SETTING PREVIEW ===" -ForegroundColor Cyan
Write-Host "Group:      $group"
Write-Host "Type:       $typeName"
Write-Host "Owner:      $owner ($mailPref)"
Write-Host "Template:   $template"
Write-Host "Department: $dept"
if ($ShouldTestMode) {
    Write-Host "NOTE: This is a DRY RUN. No changes will be made." -ForegroundColor Yellow
} else {
    Write-Host "SYSTEM READY, CONFIRM DEPLOYMENT" -ForegroundColor Green
}
Write-Host "============================="

# Confirmation before execution
if (-not $ShouldForce) {
    do {
        $confirm = Read-Host "DEPLOY AS PREVIEWED? [y/n]"
        switch -Wildcard ($confirm.ToLower()) {
            "y*" { $proceed = $true }
            "n*" {
                Write-Host "Abort command received. No changes made." -ForegroundColor Yellow
                exit 0
            }
            default { Write-Host "Please enter 'y' or 'n'." -ForegroundColor Yellow }
        }
    } while (-not $proceed)
} else {
    Write-Host "AUTHORIZATION PRE-APPROVED. Skipping confirmation prompt." -ForegroundColor Magenta
}

# Execute
if (-not $ShouldTestMode) {
    Write-Host "Creating group..."
    & "$gamPath\gam.exe" create group $group copyfrom $template name "$group $typeName Group" description "$desc"
	
	# Wait briefly to allow backend processing to catch up
    Start-Sleep -Seconds 3
	
    & "$gamPath\gam.exe" update group $group add owner $mailPref user $owner

    if (Test-Exists $group) {
        Write-Host "`nGroup creation successful" -ForegroundColor Green
		
		# Prompt for adding additional users
		$done = $false

		do {
			$addUserInput = Read-Host "`nAdd additional users? [Y] Member / [O] Owner / [M] Manager / [N] No"

			$role = $null  # reset role before switch

			switch -Wildcard ($addUserInput.ToLower()) {
				"y*" { $role = "member" }
				"o*" { $role = "owner" }
				"m*" { $role = "manager" }
				"n*" {
					Write-Host "No additional users added." -ForegroundColor Cyan
					$done = $true
				}
				default {
					Write-Host "Invalid option. Please enter Y, O, M, or N." -ForegroundColor Yellow
				}
			}

			if ($role) {
				$newUser = Read-Host "Enter email address to add as $role"

				# Strip domain if included
				if ($newUser -match "@") { $newUser = $newUser.Split("@")[0] }

				if (Test-Exists $newUser) {
					Write-Host "Adding $newUser as $role..."
					& "$gamPath\gam.exe" update group $group add $role user $newUser
					Write-Host "$newUser added as $role." -ForegroundColor Green
				} else {
					if ($newUser -notmatch "@") {
						Write-Host "ERROR: User not found and input does not contain '@'. Please try again." -ForegroundColor Red
					} else {
						Write-Host "ERROR: User '$newUser' does not exist. Please try again." -ForegroundColor Red
					}
				}
			}

		} while (-not $done)
		Show-GroupSummary "$group@burningman.org"
		
		} else {
			Write-Host "`nERROR: Group creation failed." -ForegroundColor Red
		}
	} else {
		Write-Host "`nDRY RUN: No changes were made." -ForegroundColor Yellow
	}
