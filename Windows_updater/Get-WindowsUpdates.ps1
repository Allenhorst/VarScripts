<#
    .SYNOPSIS
        Get and optionally install Windows Updates
    .DESCRIPTION
        This script will get all available udpates for the computer it is run on. 
        It will then optionally install those updates, provided they do not require 
        user input.
        
        This script was based off the original vbs that appeared on the MSDN site.
        Please see the Related Links section for the URL.
        
        Without any parameters the script will return the title of each update that
        is currently available.
    .PARAMETER Install
        When present the script will download and install each update. If the EulaAccept
        param has not been passed, only updates that don't have a Eula will be applied.
    .PARAMETER EulaAccept
        When present will allow the script to download and install all updates that are
        currently available.
    .EXAMPLE
        .\Get-WindowsUpdates.ps1
        
        There are no applicable updates
        
        Description
        -----------
        This system is currently patched and up to date.
    .NOTES
        ScriptName : Get-WindowsUpdates.ps1
        Created By : jspatton
        Date Coded : 08/29/2012 13:06:31
        ScriptName is used to register events for this script
 
        ErrorCodes
            100 = Success
            101 = Error
            102 = Warning
            104 = Information
    .LINK
        https://code.google.com/p/mod-posh/wiki/Production/Get-WindowsUpdates.ps1
    .LINK
        http://msdn.microsoft.com/en-us/library/windows/desktop/aa387102(v=vs.85).aspx
#>
$logPath = "C:\updater"
function Write-Log
{
    Param
    (
        $message
    )

    $logL = Get-Date -Format "[yyyy.MM.dd HH:mm:ss]"
    $string = $logL + "  " +  $message
    Write-Host $string
    Out-File -FilePath "$logPath\logfile.txt" -InputObject ($string)  -Append
}

function Write-ErrorLog
{
    Param
    (
        $message
    )

    $msg = "[FAILED] " + $message
    Write-Log $msg
}
function enableService
{
	$serviceInf = Get-WmiObject -Class Win32_Service  -Filter "Name='wuauserv'" -Property StartMode
		$curState =  $serviceInf.StartMode
		if($curState -like "Disabled" )
			{
			
			Set-Service -Name wuauserv -StartupType Manual
			 Write-Host "Service StartType changed"
			 $startupChanged = $true 
			Start-Service -Name wuauserv
			Write-Host "Service started"
			}
}
function disableService
{
	$serviceInf = Get-WmiObject -Class Win32_Service  -Filter "Name='wuauserv'" -Property StartMode
		$curState =  $serviceInf.StartMode
		if(!($curState -like "Disabled") )
			{
			
			
			 Write-Host "Stop Service"
			Stop-Service -Name wuauserv 
			Set-Service -Name wuauserv -StartupType Disabled
			Write-Host "Disable Start"
			}
}


function Get-WindowsUpdates
{
Param
    (
   $Install=$true,
   $EulaAccept=$true
    )
    
        $ScriptName = $MyInvocation.MyCommand.ToString()
        $ScriptPath = $MyInvocation.MyCommand.Path
        $Username = $env:USERDOMAIN + "\" + $env:USERNAME
 
        New-EventLog -Source $ScriptName -LogName 'Windows Powershell' -ErrorAction SilentlyContinue
 
        $Message = "Script: " + $ScriptPath + "`nScript User: " + $Username + "`nStarted: " + (Get-Date).toString()
        Write-EventLog -LogName 'Windows Powershell' -Source $ScriptName -EventID "104" -EntryType "Information" -Message $Message
 
        #	Dotsource in the functions you need.

        $UpdateSession = New-Object -ComObject 'Microsoft.Update.Session'
        $UpdateSession.ClientApplicationID = 'MSDN PowerShell Sample'
     
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
		#Specify search criteria , for categoryID see this document : https://msdn.microsoft.com/en-us/library/ff357803(v=vs.85).aspx
        $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0 and CategoryIDs contains  'E6CF1350-C01B-414D-A61F-263D14D133B4'")
        
        if ($Install)
        {
            Write-Log 'Creating a collection of updates to download:'
			
            $UpdatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
            foreach ($Update in $SearchResult.Updates)
            {
                [bool]$addThisUpdate = $false
                if ($Update.InstallationBehavior.CanRequestUserInput)
                {
                    Write-Log "> Skipping: $($Update.Title) because it requires user input"
                    }
                else
                {
                    if (!($Update.EulaAccepted))
                    {
                        Write-Log "> Note: $($Update.Title) has a license agreement that must be accepted:"
                        if ($EulaAccept)
                        {
                            $Update.AcceptEula()
                            [bool]$addThisUpdate = $true
                            }
                        else
                        {
                            Write-Log "> Skipping: $($Update.Title) because the license agreement was declined"
                            }
                        }
                    else
                    {
                        [bool]$addThisUpdate = $true
                        }
                    }
                if ([bool]$addThisUpdate)
                {
                    Write-Log "Adding: $($Update.Title)"
                    $UpdatesToDownload.Add($Update) |Out-Null
                    }
                }
            if ($UpdatesToDownload.Count -eq 0)
            {
                Write-Log 'All applicable updates were skipped.'
                break
                }

            Write-Log 'Downloading updates...'
            $Downloader = $UpdateSession.CreateUpdateDownloader()
            $Downloader.Updates = $UpdatesToDownload
            $Downloader.Download()

            $UpdatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

            [bool]$rebootMayBeRequired = $false
            Write-Log 'Successfully downloaded updates:'

            foreach ($Update in $SearchResult.Updates)
            {
                if ($Update.IsDownloaded)
                {
                    Write-Log "> $($Update.Title)"
                    $UpdatesToInstall.Add($Update) |Out-Null
                    
                    if ($Update.InstallationBehavior.RebootBehavior -gt 0)
                    {
                        [bool]$rebootMayBeRequired = $true
                        }
                    }
                }
            if ($UpdatesToInstall.Count -eq 0)
            {
                Write-Log 'No updates were successfully downloaded'
                }

            if ($rebootMayBeRequired)
            {
                Write-Log 'These updates may require a reboot'
                }

            Write-Log 'Installing updates...'
            
            $Installer = $UpdateSession.CreateUpdateInstaller()
            $Installer.Updates = $UpdatesToInstall
            $InstallationResult = $Installer.Install()
            
            Write-Log "Installation Result: $($InstallationResult.ResultCode)"
            Write-Log "Reboot Required: $($InstallationResult.RebootRequired)"
            Write-Log 'Listing of updates installed and individual installation results'
            
            for($i=0; $i -lt $UpdatesToInstall.Count; $i++)
            {
                New-Object -TypeName PSObject -Property @{
                    Title = $UpdatesToInstall.Item($i).Title
                    Result = $InstallationResult.GetUpdateResult($i).ResultCode
                    }
                }
            }
        else
        {
            if ($SearchResult.Updates.Count -ne 0)
            {
                $SearchResult.Updates |Select-Object -Property Title, Description, SupportUrl, UninstallationNotes, RebootRequired |Format-List
                }
            else
            {
                Write-Host 'There are no applicable updates'
                }
            }

        $Message = "Script: " + $ScriptPath + "`nScript User: " + $Username + "`nFinished: " + (Get-Date).toString()
        Write-EventLog -LogName 'Windows Powershell' -Source $ScriptName -EventID "104" -EntryType "Information" -Message $Message	
    }
	
	 Write-log "starting execution"
enableService
Get-WindowsUpdates
disableService 
Write-log "end of execution"
