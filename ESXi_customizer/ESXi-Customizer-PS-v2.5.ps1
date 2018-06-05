#############################################################################################################################
#
# ESXi-Customizer-PS.ps1 - a script to build a customized ESXi installation ISO using ImageBuilder
#
# Version:       2.5.0
# Author:        Andreas Peetz (ESXi-Customizer-PS@v-front.de)
# Info/Tutorial: https://esxi-customizer-ps.v-front.de/
#
# License:
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# A copy of the GNU General Public License is available at http://www.gnu.org/licenses/.
#
#############################################################################################################################
#
# NOTE: This script is SIGNED. Please remove the signature block at the end of the file before modifying it!
#
#############################################################################################################################

param(
    [string]$iZip = "",
    [string]$pkgDir = "",
    [string]$outDir = $(Split-Path $MyInvocation.MyCommand.Path),
    [string]$ipname = "",
    [string]$ipvendor = "",
    [string]$ipdesc = "",
    [switch]$vft = $false,
    [string[]]$dpt = @(),
    [string[]]$load = @(),
    [string[]]$remove = @(),
    [switch]$test = $false,
    [switch]$sip = $false,
    [switch]$nsc = $false,
    [switch]$help = $false,
    [switch]$ozip = $false,
    [switch]$v50 = $false,
    [switch]$v51 = $false,
    [switch]$v55 = $false,
    [switch]$v60 = $false,
    [switch]$v65 = $false,
    [switch]$update = $false,
    [string]$log = ($env:TEMP + "\ESXi-Customizer-PS-" + $PID + ".log")
)

# Constants
$ScriptName = "ESXi-Customizer-PS"
$ScriptVersion = "2.5.0"
$ScriptURL = "https://ESXi-Customizer-PS.v-front.de"

$AccLevel = @{"VMwareCertified" = 1; "VMwareAccepted" = 2; "PartnerSupported" = 3; "CommunitySupported" = 4}

# Online depot URLs
$vmwdepotURL = "https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml"
$vftdepotURL = "https://vibsdepot.v-front.de/"

# Function to update/add VIB package
function AddVIB2Profile($vib) {
    $AddVersion = $vib.Version
    $ExVersion = ($MyProfile.VibList | where { $_.Name -eq $vib.Name }).Version
    if ($AccLevel[$vib.AcceptanceLevel.ToString()] -gt $AccLevel[$MyProfile.AcceptanceLevel.ToString()]) {
        write-host -ForegroundColor Yellow -nonewline (" [New AcceptanceLevel: " + $vib.AcceptanceLevel + "]")
        $MyProfile.AcceptanceLevel = $vib.AcceptanceLevel
    }
    If ($MyProfile.VibList -contains $vib) {
        write-host -ForegroundColor Yellow " [IGNORED, already added]"
    } else {
        Add-EsxSoftwarePackage -SoftwarePackage $vib -Imageprofile $MyProfile -force -ErrorAction SilentlyContinue | Out-Null 
        if ($?) {
            if ($ExVersion -eq $null) {
                write-host -ForegroundColor Green " [OK, added]"
            } else {
                write-host -ForegroundColor Yellow (" [OK, replaced " + $ExVersion + "]")
            }
        } else {
            write-host -ForegroundColor Red " [FAILED, invalid package?]"
        }
    }
}

# Function to test if entered string is numeric
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
}

# Clean-up function
function cleanup() {
    Stop-Transcript | Out-Null
    if ($DefaultSoftwaredepots) { Remove-EsxSoftwaredepot $DefaultSoftwaredepots }
}

# Set up the screen
$pswindow = (get-host).ui.rawui
$newsize = $pswindow.buffersize
if ( $newsize.height -lt 3000) { $newsize.height = 3000 }
if ( $newsize.width -lt 120) { $newsize.width = 120 }
$pswindow.buffersize = $newsize
$newsize = $pswindow.windowsize
if ( $newsize.height -lt 50) { $newsize.height = ((get-host).UI.RawUI.MaxWindowSize.Height,50 | Measure -Minimum).Minimum }
if ( $newsize.width -lt 120) { $newsize.width = ((get-host).UI.RawUI.MaxWindowSize.Width,120 | Measure -Minimum).Minimum }
$pswindow.windowsize = $newsize
$pswindow.windowtitle = $ScriptName + " " + $ScriptVersion + " - " + $ScriptUrl
$pswindow.foregroundcolor = "White"
$pswindow.backgroundcolor = "Black"

# Write info and help if requested
write-host ("`nThis is " + $ScriptName + " Version " + $ScriptVersion + " (visit " + $ScriptURL + " for more information!)")
if ($help) {
    write-host "`nUsage:"
    write-host "   ESXi-Customizer-PS [-help] | [-izip <bundle> [-update]] [-sip] [-v50|-v51|-v55|-v60|-v65] [-ozip] [-pkgDir <dir>]"
    write-host "                                [-outDir <dir>] [-vft] [-dpt depot1[,...]] [-load vib1[,...]] [-remove vib1[,...]]"
    write-host "                                [-log <file>] [-ipname <name>] [-ipdesc <desc>] [-ipvendor <vendor>] [-nsc] [-test]"
    write-host "`nOptional parameters:"
    write-host "   -help              : display this help"
    write-host "   -izip <bundle>     : use the VMware Offline bundle <bundle> as input instead of the Online depot"
    write-host "   -update            : only with -izip, updates a local bundle with an ESXi patch from the VMware Online depot,"
    write-host "                        combine this with the matching ESXi version selection switch"
    write-host "   -pkgDir <dir>      : local directory of Offline bundles and/or VIB files to add (if any, no default)"
    write-host "   -ozip              : output an Offline bundle instead of an installation ISO"
    write-host "   -outDir <dir>      : directory to store the customized ISO or Offline bundle (the default is the"
    write-host "                        script directory. If specified the log file will also be moved here.)"
    write-host "   -vft               : connect the V-Front Online depot"
	write-host "   -dpt depot1[,...]  : connect additional Online depots by URL or local Offline bundles by file name"
    write-host "   -load vib1[,...]   : load additional packages from connected depots or Offline bundles"
    write-host "   -remove vib1[,...] : remove named VIB packages from the custom Imageprofile"
    write-host "   -sip               : select an Imageprofile from the current list"
    write-host "                        (default = auto-select latest available standard profile)"
    write-host "   -v50 | -v51 | -v55 |"
    write-host "   -v60 | -v65        : Use only ESXi 5.0/5.1/5.5/6.0/6.5 Imageprofiles as input, ignore other versions"
    write-host "   -nsc               : use -NoSignatureCheck with export"
    write-host "   -log <file>        : Use custom log file <file>"
    write-host "   -ipname <name>"
    write-host "   -ipdesc <desc>"
    write-host "   -ipvendor <vendor> : provide a name, description and/or vendor for the customized"
    write-host "                        Imageprofile (the default is derived from the cloned input Imageprofile)"
    write-host "   -test              : skip package download and image build (for testing)`n"
    exit
} else {
    write-host "(Call with -help for instructions)"
    if (!($PSBoundParameters.ContainsKey('log')) -and $PSBoundParameters.ContainsKey('outDir')) {
        write-host ("`nTemporarily logging to " + $log + " ...")
    } else {
        write-host ("`nLogging to " + $log + " ...")
    }
    # Stop active transcript
    try { Stop-Transcript | out-null } catch {}
    # Start own transcript
    try { Start-Transcript -Path $log -Force -Confirm:$false | Out-Null } catch {
        write-host -ForegroundColor Red "`nFATAL ERROR: Log file cannot be opened. Bad file path or missing permission?`n"
        exit
    }
}

# The main try ...
try {

# Check for and load required modules/snapins
foreach ($comp in "VMware.VimAutomation.Core", "VMware.ImageBuilder") {
    if (Get-Module -ListAvailable -Name $comp -ErrorAction:SilentlyContinue) {
        if (!(Get-Module -Name $comp -ErrorAction:SilentlyContinue)) {
            if (!(Import-Module -PassThru -Name $comp -ErrorAction:SilentlyContinue)) {
                write-host -ForegroundColor Red "`nFATAL ERROR: Failed to import the $comp module!`n"
                exit
            }
        }
    } else {
        if (Get-PSSnapin -Registered -Name $comp -ErrorAction:SilentlyContinue) {
            if (!(Get-PSSnapin -Name $comp -ErrorAction:SilentlyContinue)) {
                if (!(Add-PSSnapin -PassThru -Name $comp -ErrorAction:SilentlyContinue)) {
                    write-host -ForegroundColor Red "`nFATAL ERROR: Failed to add the $comp snapin!`n"
                    exit
                }
            }
        } else {
            write-host -ForegroundColor Red "`nFATAL ERROR: $comp is not available as a module or snapin! It looks like there is no compatible version of PowerCLI installed!`n"
            exit
        }
    }
}

# Parameter sanity check
if ( ($v50 -and ($v51 -or $v55 -or $v60 -or $v65)) -or ($v51 -and ($v55 -or $v60 -or $v65)) -or ($v55 -and ($v60 -or $v65)) -or ($v60 -and $v65) ) {
    write-host -ForegroundColor Yellow "`nWARNING: Multiple ESXi versions specified. Highest version will take precedence!"
}
if ($update -and ($izip -eq "")) {
    write-host -ForegroundColor Red "`nFATAL ERROR: -update requires -izip!`n"
    exit
}

# Check PowerShell and PowerCLI version
if (!(Test-Path variable:PSVersionTable)) {
    write-host -ForegroundColor Red "`nFATAL ERROR: This script requires at least PowerShell version 2.0!`n"
    exit
}
$psv = $PSVersionTable.PSVersion | select Major,Minor
$pcv = Get-PowerCLIVersion | select major,minor,UserFriendlyVersion
write-host ("`nRunning with PowerShell version " + $psv.Major + "." + $psv.Minor + " and " + $pcv.UserFriendlyVersion)

if ( ($pcv.major -lt 5) -or (($pcv.major -eq 5) -and ($pcv.minor -eq 0)) ) {
    write-host -ForegroundColor Red "`nFATAL ERROR: This script requires at least PowerCLI version 5.1 !`n"
    exit
}

if ($update) {
    # Try to add Offline bundle specified by -izip
    write-host -nonewline "`nAdding Base Offline bundle $izip (to be updated)..."
    if ($upddepot = Add-EsxSoftwaredepot $izip) {
        write-host -ForegroundColor Green " [OK]"
    } else {
        write-host -ForegroundColor Red "`nFATAL ERROR: Cannot add Base Offline bundle!`n"
        exit
    }
    if (!($CloneIP = Get-EsxImageprofile -Softwaredepot $upddepot)) {
        write-host -ForegroundColor Red "`nFATAL ERROR: No Imageprofiles found in Base Offline bundle!`n"
        exit
    }
    if ($CloneIP -is [system.array]) {
        # Input Offline bundle includes multiple Imageprofiles. Pick only the latest standard profile:
        write-host -ForegroundColor Yellow "Warning: Input Offline Bundle contains multiple Imageprofiles. Will pick the latest standard profile!"
        $CloneIP = @( $CloneIP | Sort-Object -Descending -Property @{Expression={$_.Name.Substring(0,10)}},@{Expression={$_.CreationTime.Date}},Name )[0]
    }
}

if (($izip -eq "") -or $update) {
    # Connect the VMware ESXi base depot
    write-host -nonewline "`nConnecting the VMware ESXi Online depot ..."
    if ($basedepot = Add-EsxSoftwaredepot $vmwdepotURL) {
        write-host -ForegroundColor Green " [OK]"
    } else {
        write-host -ForegroundColor Red "`nFATAL ERROR: Cannot add VMware ESXi Online depot. Please check your Internet connectivity and/or proxy settings!`n"
        exit
    }
} else {
    # Try to add Offline bundle specified by -izip
    write-host -nonewline "`nAdding base Offline bundle $izip ..."
    if ($basedepot = Add-EsxSoftwaredepot $izip) {
        write-host -ForegroundColor Green " [OK]"
    } else {
        write-host -ForegroundColor Red "`nFATAL ERROR: Cannot add VMware base Offline bundle!`n"
        exit
    }
}

if ($vft) {
    # Connect the V-Front Online depot
    write-host -nonewline "`nConnecting the V-Front Online depot ..."
    if ($vftdepot = Add-EsxSoftwaredepot $vftdepotURL) {
        write-host -ForegroundColor Green " [OK]"
    } else {
        write-host -ForegroundColor Red "`nFATAL ERROR: Cannot add the V-Front Online depot. Please check your internet connectivity and/or proxy settings!`n"
        exit
    }
}

if ($dpt -ne @()) {
	# Connect additional depots (Online depot or Offline bundle)
	$AddDpt = @()
	for ($i=0; $i -lt $dpt.Length; $i++ ) {
		write-host -nonewline ("`nConnecting additional depot " + $dpt[$i] + " ...")
		if ($AddDpt += Add-EsxSoftwaredepot $dpt[$i]) {
			write-host -ForegroundColor Green " [OK]"
		} else {
			write-host -ForegroundColor Red "`nFATAL ERROR: Cannot add Online depot or Offline bundle. In case of Online depot check your Internet"
            write-host -ForegroundColor Red "connectivity and/or proxy settings! In case of Offline bundle check file name, format and permissions!`n"
			exit
		}
	}

}

write-host -NoNewLine "`nGetting Imageprofiles, please wait ..."
$iplist = @()
if ($iZip -and !($update)) {
    Get-EsxImageprofile -Softwaredepot $basedepot | foreach { $iplist += $_ }
} else {
    if ($v65) {
        Get-EsxImageprofile "ESXi-6.5*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
    } else {
        if ($v60) {
            Get-EsxImageprofile "ESXi-6.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
        } else {
            if ($v55) {
                Get-EsxImageprofile "ESXi-5.5*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
            } else {
                if ($v51) {
                    Get-EsxImageprofile "ESXi-5.1*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
                } else {
                    if ($v50) {
                        Get-EsxImageprofile "ESXi-5.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
                    } else {
                        # Workaround for http://kb.vmware.com/kb/2089217
                        Get-EsxImageprofile "ESXi-5.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
                        Get-EsxImageprofile "ESXi-5.1*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
                        Get-EsxImageprofile "ESXi-5.5*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
                        Get-EsxImageprofile "ESXi-6.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
                        Get-EsxImageprofile "ESXi-6.5*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
                    }
                }
            }
        }
    }
}

if ($iplist.Length -eq 0) {
    write-host -ForegroundColor Red " [FAILED]`n`nFATAL ERROR: No valid Imageprofile(s) found!"
    if ($iZip) {
        write-host -ForegroundColor Red "The input file is probably not a full ESXi base bundle.`n"
    }
    exit
} else {
    write-host -ForegroundColor Green " [OK]"
    $iplist = @( $iplist | Sort-Object -Descending -Property @{Expression={$_.Name.Substring(0,10)}},@{Expression={$_.CreationTime.Date}},Name )
}

# if -sip then display menu of available image profiles ...
if ($sip) {
    if ($update) {
        write-host "`nSelect Imageprofile to use for update:"
    } else {
        write-host "`nSelect Base Imageprofile:"
    }
    write-host "-------------------------------------------"
    for ($i=0; $i -lt $iplist.Length; $i++ ) {
        write-host ($i+1): $iplist[$i].Name
    }
    write-host "-------------------------------------------"
    do {
        $sel = read-host "Enter selection"
        if (isNumeric $sel) {
            if (([int]$sel -lt 1) -or ([int]$sel -gt $iplist.Length)) { $sel = $null }
        } else {
            $sel = $null
        }
    } until ($sel)
    $idx = [int]$sel-1
} else {
    $idx = 0
}
if ($update) {
    $updIP = $iplist[$idx]
} else {
    $CloneIP = $iplist[$idx]
}

write-host ("`nUsing Imageprofile " + $CloneIP.Name + " ...")
write-host ("(dated " + $CloneIP.CreationTime + ", AcceptanceLevel: " + $CloneIP.AcceptanceLevel + ",")
write-host ($CloneIP.Description + ")")

# If customization is required ...
if ( ($pkgDir -ne "") -or $update -or ($load -ne @()) -or ($remove -ne @()) ) {

    # Create your own Imageprofile
    if ($ipname -eq "") { $ipname = $CloneIP.Name + "-customized" }
    if ($ipvendor -eq "") { $ipvendor = $CloneIP.Vendor }
    if ($ipdesc -eq "") { $ipdesc = $CloneIP.Description + " (customized)" }
    $MyProfile = New-EsxImageprofile -CloneProfile $CloneIP -Vendor $ipvendor -Name $ipname -Description $ipdesc

    # Update from Online depot profile
    if ($update) {
        write-host ("`nUpdating with the VMware Imageprofile " + $UpdIP.Name + " ...")
        write-host ("(dated " + $UpdIP.CreationTime + ", AcceptanceLevel: " + $UpdIP.AcceptanceLevel + ",")
        write-host ($UpdIP.Description + ")")
        $diff = Compare-EsxImageprofile $MyProfile $UpdIP
        $diff.UpgradeFromRef | foreach {
            $uguid = $_
            $uvib = Get-EsxSoftwarePackage | where { $_.Guid -eq $uguid }
            write-host -nonewline "   Add VIB" $uvib.Name $uvib.Version
            AddVIB2Profile $uvib
        }
    }

    # Loop over Offline bundles and VIB files
    if ($pkgDir -ne "") {
        write-host "`nLoading Offline bundles and VIB files from" $pkgDir ...
        foreach ($obundle in Get-Item $pkgDir\*.zip) {
            write-host -nonewline "   Loading" $obundle ...
            if ($ob = Add-EsxSoftwaredepot $obundle -ErrorAction SilentlyContinue) {
                write-host -ForegroundColor Green " [OK]"
                $ob | Get-EsxSoftwarePackage | foreach {
                    write-host -nonewline "      Add VIB" $_.Name $_.Version
                    AddVIB2Profile $_
                }
            } else {
                write-host -ForegroundColor Red " [FAILED]`n      Probably not a valid Offline bundle, ignoring."
            }
        }
        foreach ($vibFile in Get-Item $pkgDir\*.vib) {
            write-host -nonewline "   Loading" $vibFile ...
            try {
                $vib1 = Get-EsxSoftwarePackage -PackageUrl $vibFile -ErrorAction SilentlyContinue
                write-host -ForegroundColor Green " [OK]"
                write-host -nonewline "      Add VIB" $vib1.Name $vib1.Version
                AddVIB2Profile $vib1
            } catch {
                write-host -ForegroundColor Red " [FAILED]`n      Probably not a valid VIB file, ignoring."
            }
        }
    }
    # Load additional packages from Online depots or Offline bundles
    if ($load -ne @()) {
        write-host "`nLoad additional VIBs from Online depots ..."
        for ($i=0; $i -lt $load.Length; $i++ ) {
            if ($ovib = Get-ESXSoftwarePackage $load[$i] -Newest) {
                write-host -nonewline "   Add VIB" $ovib.Name $ovib.Version
                AddVIB2Profile $ovib
            } else {
                write-host -ForegroundColor Red "   [ERROR] Cannot find VIB named" $load[$i] "!"
            }
        }
    }
    # Remove selected VIBs
    if ($remove -ne @()) {
        write-host "`nRemove selected VIBs from Imageprofile ..."
        for ($i=0; $i -lt $remove.Length; $i++ ) {
            write-host -nonewline "      Remove VIB" $remove[$i]
            try {
                Remove-EsxSoftwarePackage -ImageProfile $MyProfile -SoftwarePackage $remove[$i] | Out-Null
                write-host -ForegroundColor Green " [OK]"
            } catch {
                write-host -ForegroundColor Red " [FAILED]`n      VIB does probably not exist or cannot be removed without breaking dependencies."
            }
        }
    }

} else {
    $MyProfile = $CloneIP
}


# Build the export command:
$cmd = "Export-EsxImageprofile -Imageprofile " + "`'" + $MyProfile.Name + "`'"

if ($ozip) {
    $outFile = "`'" + $outDir + "\" + $MyProfile.Name + ".zip" + "`'"
    $cmd = $cmd + " -ExportTobundle"
} else {
    $outFile = "`'" + $outDir + "\" + $MyProfile.Name + ".iso" + "`'"
    $cmd = $cmd + " -ExportToISO"
}
$cmd = $cmd + " -FilePath " + $outFile
if ($nsc) { $cmd = $cmd + " -NoSignatureCheck" }
$cmd = $cmd + " -Force"

# Run the export:
write-host -nonewline ("`nExporting the Imageprofile to " + $outFile + ". Please be patient ...")
if ($test) {
    write-host -ForegroundColor Yellow " [Skipped]"
} else {
    write-host "`n"
    Invoke-Expression $cmd
}

write-host -ForegroundColor Green "`nAll done.`n"

# The main catch ...
} catch {
    write-host -ForegroundColor Red ("`n`nAn unexpected error occured:`n" + $Error[0])
    write-host -ForegroundColor Red ("`nIf requesting support please be sure to include the log file`n   " + $log + "`n`n")

# The main cleanup
} finally {
    cleanup
    if (!($PSBoundParameters.ContainsKey('log')) -and $PSBoundParameters.ContainsKey('outDir')) {
        $finalLog = ($outDir + "\" + $MyProfile.Name + "-" + (get-date -Format yyyyMMddHHmm) + ".log")
        Move-Item $log $finalLog -force
        write-host ("(Log file moved to " + $finalLog + ")`n")
    }
}

# SIG # Begin signature block
# MIIZmAYJKoZIhvcNAQcCoIIZiTCCGYUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUhNOPMV9wNhjsQh2+/yul/7go
# hhygghS5MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggXZMIIDwaADAgECAgcQAPXr4DlDMA0GCSqGSIb3DQEBCwUAMH0xCzAJBgNVBAYT
# AklMMRYwFAYDVQQKEw1TdGFydENvbSBMdGQuMSswKQYDVQQLEyJTZWN1cmUgRGln
# aXRhbCBDZXJ0aWZpY2F0ZSBTaWduaW5nMSkwJwYDVQQDEyBTdGFydENvbSBDZXJ0
# aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0wNzEwMTQyMjAxNDZaFw0yMjEwMTQyMjAx
# NDZaMIGMMQswCQYDVQQGEwJJTDEWMBQGA1UEChMNU3RhcnRDb20gTHRkLjErMCkG
# A1UECxMiU2VjdXJlIERpZ2l0YWwgQ2VydGlmaWNhdGUgU2lnbmluZzE4MDYGA1UE
# AxMvU3RhcnRDb20gQ2xhc3MgMiBQcmltYXJ5IEludGVybWVkaWF0ZSBPYmplY3Qg
# Q0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDKI4siNR6aoBs8nUnQ
# PwyXOBYpuvh9iVtFWO+EcO1+EU3pFDGrQ+NNDFGBbPAVA0okJ1Tl+0qgzk3hhKMh
# 3pk1q9xJrr8xxWeEMBCb7wfcdagPTfQ1U7FuOAP8iHcdpXf/P3Xn2ee/LFARyRFl
# +kkHYp+TpoepbcmdK9F75dVlK58NUJ7++3EZITAoJo2uwtz2luhShggLejLNahRN
# nrn5zQfilpHxzx4r+YL3XiYGjo3R1DnXb9uRJ1p5j1hpCka1b+H9b8WRtBFPewKm
# 20tWUiOeS5jiv37O+qFOg+PFx8NgR/5cPxUaQCqV7wBryFD4zWoZ1CMDJ7w7NtW5
# Q7DvAgMBAAGjggFMMIIBSDASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQE
# AwIBBjAdBgNVHQ4EFgQU0E4PQJlsuEsZbzsouODjiAc0qrcwHwYDVR0jBBgwFoAU
# TgvvGqRAW6UXaYcwyjRoQ9BBrvIwaQYIKwYBBQUHAQEEXTBbMCcGCCsGAQUFBzAB
# hhtodHRwOi8vb2NzcC5zdGFydHNzbC5jb20vY2EwMAYIKwYBBQUHMAKGJGh0dHA6
# Ly9haWEuc3RhcnRzc2wuY29tL2NlcnRzL2NhLmNydDAyBgNVHR8EKzApMCegJaAj
# hiFodHRwOi8vY3JsLnN0YXJ0c3NsLmNvbS9zZnNjYS5jcmwwQwYDVR0gBDwwOjA4
# BgRVHSAAMDAwLgYIKwYBBQUHAgEWImh0dHA6Ly93d3cuc3RhcnRzc2wuY29tL3Bv
# bGljeS5wZGYwDQYJKoZIhvcNAQELBQADggIBADWy5WYXlCb0MUBWc0fp3GMiOWfc
# R2i2lmlNINajPswiLayT6kezsqbTACTYI3vBKk4gBsyfoB50VuZb3ByPyVGU0adb
# OkIwC+ae7/b6sQqMjjA8sNQq8vukfVV2qSUNUneFkyrB/GOl6RoZoha42EvQ1ZwY
# en/ezWlaNIiG4TT96NSdkGlrN9CTag/u5OQ+Z8bimy+BkVW6FyV8zMruFmrzMb86
# j1A51oXOA4EUsyRDyaclhlxkEajrlXZqb9oMNmZNbX8dj852tjDtptkJj+OWIcO2
# 8vBaEQ2jBQSbosM1O6W+BxM8tBeYvirDv6sXsULMxl2n9DEqghrkLL4dkNwTKvXv
# +ymA+ollik0+qinrM6D6jVyjzg1fPIza13NXNjoJhgch03IQd7ppQOdA0yySkqhC
# BqstaFNOaLfELHzqd2Cd3rAU8ZPlfwnxHk5z/5MZHECjnb3pyrZSdQLwqnaYt3GE
# GH3MxiRyejervfwYEyoHf9pIeLACbYYO/3uXdj68KKGJzJbvQa1KKMwNfi0btYzT
# EECilNhOKsdpL4dBaTLGDrkPQJB3BZBLqukVaPDienIS4Hsxy0FgYD1PtFGB0eg2
# JfcBhuyVloHBLZwuJXGEjAhyKE84gBDKyaVHN41cMgSZdQ6jUcfZYxWV0MbxDJMo
# 2tLZ8sjB+aPb5IipMIIGPzCCBSegAwIBAgIHErp40Fk4zjANBgkqhkiG9w0BAQsF
# ADCBjDELMAkGA1UEBhMCSUwxFjAUBgNVBAoTDVN0YXJ0Q29tIEx0ZC4xKzApBgNV
# BAsTIlNlY3VyZSBEaWdpdGFsIENlcnRpZmljYXRlIFNpZ25pbmcxODA2BgNVBAMT
# L1N0YXJ0Q29tIENsYXNzIDIgUHJpbWFyeSBJbnRlcm1lZGlhdGUgT2JqZWN0IENB
# MB4XDTE1MDgyOTIwMTA0M1oXDTE3MDgzMDE2MDYzNVowczELMAkGA1UEBhMCREUx
# DzANBgNVBAgTBkhlc3NlbjESMBAGA1UEBxMJRnJhbmtmdXJ0MRYwFAYDVQQDEw1B
# bmRyZWFzIFBlZXR6MScwJQYJKoZIhvcNAQkBFhhzdGFydGNvbUBwZWV0ei1vbmxp
# bmUuZGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQChAM2NaQVWdrUN
# 6KByaJghz4tPn/dSHKJ2jy9571oV1gsqv9n7BKSl7JhmSD1kWbLSTVsCIhhX7cR7
# 88xvJ/603rmO5nfQwSv4jkX4sTL2IUmR5ccaqMJ0o4YkXiFu7P5+G0z1rU7whf8H
# DvLfqA0R3VBIgVbJX/vAVb/I3rVm3YrkB5Rt5GMBHnTK1JVahMyqqB/8cRp03hCg
# 3V5EOK6rS5iNBN76FEW/EdygwgYvoovh0p2LMITCDZUqXAP1qXdI+hp4eLOK1ss9
# z+vX7uwe+Dcu8sciPubRP1CkURjfR7KOiwvJLLeC/GfOMrPZ1yEhL3lUAL5Pt3LY
# vzyUkt2TAgMBAAGjggK8MIICuDAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIHgDAi
# BgNVHSUBAf8EGDAWBggrBgEFBQcDAwYKKwYBBAGCNwoDDTAdBgNVHQ4EFgQUlJcn
# ea/2YeA6HbZ7EmaLBBLzBM4wHwYDVR0jBBgwFoAU0E4PQJlsuEsZbzsouODjiAc0
# qrcwggFMBgNVHSAEggFDMIIBPzCCATsGCysGAQQBgbU3AQIDMIIBKjAuBggrBgEF
# BQcCARYiaHR0cDovL3d3dy5zdGFydHNzbC5jb20vcG9saWN5LnBkZjCB9wYIKwYB
# BQUHAgIwgeowJxYgU3RhcnRDb20gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwAwIB
# ARqBvlRoaXMgY2VydGlmaWNhdGUgd2FzIGlzc3VlZCBhY2NvcmRpbmcgdG8gdGhl
# IENsYXNzIDIgVmFsaWRhdGlvbiByZXF1aXJlbWVudHMgb2YgdGhlIFN0YXJ0Q29t
# IENBIHBvbGljeSwgcmVsaWFuY2Ugb25seSBmb3IgdGhlIGludGVuZGVkIHB1cnBv
# c2UgaW4gY29tcGxpYW5jZSBvZiB0aGUgcmVseWluZyBwYXJ0eSBvYmxpZ2F0aW9u
# cy4wNgYDVR0fBC8wLTAroCmgJ4YlaHR0cDovL2NybC5zdGFydHNzbC5jb20vY3J0
# YzItY3JsLmNybDCBiQYIKwYBBQUHAQEEfTB7MDcGCCsGAQUFBzABhitodHRwOi8v
# b2NzcC5zdGFydHNzbC5jb20vc3ViL2NsYXNzMi9jb2RlL2NhMEAGCCsGAQUFBzAC
# hjRodHRwOi8vYWlhLnN0YXJ0c3NsLmNvbS9jZXJ0cy9zdWIuY2xhc3MyLmNvZGUu
# Y2EuY3J0MCMGA1UdEgQcMBqGGGh0dHA6Ly93d3cuc3RhcnRzc2wuY29tLzANBgkq
# hkiG9w0BAQsFAAOCAQEABjDQz7pe5gj3MLPYqBKWaoHG2OdncayWWWr5isYydPAq
# PrDZCh7nQ5t7qgKNIZ6wuq80QvvtgAu8GOw8YCcrYpkBqgiwPuQMiEbkZHTs6HDk
# 4RyX5DO4QlH7VDAWz0FnJEehF/L6C3FgkdJZT3JZWsFwU8+xxLKEZhvbpJoQH6It
# kROwRXxwN3NPydmSRM8qVZQ+nDDuBlrl4rxTF99o7SYx1kLUQLMpH1oEO8WaWKJd
# A9LcvkGjn5RMrTHGD5ItCYh7hAlgFB38gpZmtamSdaMVQefqrxYX++azXK3vWlMd
# fad0nUr8kKi1pEzTd5nVPBvVIB7pggjJSbZMRggK2zGCBEkwggRFAgEBMIGYMIGM
# MQswCQYDVQQGEwJJTDEWMBQGA1UEChMNU3RhcnRDb20gTHRkLjErMCkGA1UECxMi
# U2VjdXJlIERpZ2l0YWwgQ2VydGlmaWNhdGUgU2lnbmluZzE4MDYGA1UEAxMvU3Rh
# cnRDb20gQ2xhc3MgMiBQcmltYXJ5IEludGVybWVkaWF0ZSBPYmplY3QgQ0ECBxK6
# eNBZOM4wCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFMRA5064T8ig2WGFvMEwQXGQLZbTMA0GCSqG
# SIb3DQEBAQUABIIBAHQ9+t1rD3VTV/koTZuF4/2573pOFlW9vcLylZXrHrrafQGZ
# BSPck73ywXyibIfCQl+obXXyiGFE4qZo0ihNJDBl1XKPUBI6cgfY+OpOpq/9D6Vz
# YUNpXyH8MjIZEyA4GlmYsC9btRmXQC2I0xh1ix7XPIuMqHirdjIswcGOjZrnk0Au
# /BhFUgOsE1M8kWXecl21jLLt3Gfp4vxRMYgq0d1+85BM+XiGLjrfFwx6hK4lBi6O
# Jy8I15qV0UY0FEksqrymW0q3NN5anSB19uZ5lopQ5+TzLaWGREuYEZIf0QAPUE7l
# x/MQSLxny1OkOr38vDEryT/Ll5BNcYaIJ0rsdUKhggILMIICBwYJKoZIhvcNAQkG
# MYIB+DCCAfQCAQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMg
# Q29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2Vy
# dmljZXMgQ0EgLSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJ
# KoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTYxMTIzMDky
# MTU0WjAjBgkqhkiG9w0BCQQxFgQUW4begI+TjCBw7F5EVZhjg2Yd70UwDQYJKoZI
# hvcNAQEBBQAEggEAXHUJ4C6HR55PB+Bg0L+SMIO46qw1R7gkOMqaeuhnetl8JtL9
# ubThMiCy4I7B4JMGkgPM2fkz1kyUSCoaLSwQVYwaaxvLlasyiATch+qWcALhnSfp
# J5/+JjDlTcmZ453NXRN18P7LX0fl46PhSzgHj7f4fycU5EGrraX5kgVfY5E7SH7V
# Y+gIfDQfbCA7WXK5v4L5cD/EZo3rtYjRE1Dr4DstsE7BkX6eK5BsG0MWs5ar/s2R
# mxz/R7SkfVNnxfX2/ZmzyF+FBZwPL1CSGaiDf//eZvoF5P9KVGbp76j4Swn7gFPX
# yTJgBRqg3YszreiFeag9QPYPbp0C2wm518LhEQ==
# SIG # End signature block
