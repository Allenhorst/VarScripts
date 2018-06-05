
param (
    <#[Parameter(Mandatory=$true)]#> [String] $oldDeskId = "37",
    <#[Parameter(Mandatory=$true)]#> [String] $newDeskId = "37",
    <#[Parameter(Mandatory=$true)]#> [String] $esxHost = "sb604.paragon-software.com",
    [String] $vcenter = "vcenter-dlg-prm",
#    [String] $oldDeskId = "66",
#    [String] $newDeskId = "99",
    [String] $esxHost2 = "sb604",
    [String] $vcenterUserName = "paragon\autotester",
    [String] $vcenterPassword = "asdF5hh",
    [String] $esxUserName = "autotester",
    [String] $esxPassword = "asdF5hh",
    [String] $vmDomainName = "prm-domain",
#    [String] $vmArmNameList = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620went64en,prm-ct-??",
    [String] $vmArmNameList = "w???wpro??en,w???sstd??en,w???sweb??en,w???wbus??en,w???went??en,prm-ct-??",
    [String] $vmTargetNameList = "PRM-AT-??,PRM-BT-??",
    [String] $vmArmSnapshotList = "Clear,Base-clear,Base,Domain,ADK,ExtendedSoft",
    [String] $vmDomainSnapshotName = "Domain",
    [String] $networkName = "testnetwork",
    [String] $logFolderPath = ($env:TEMP + "\RENAMING_"+(Get-Date -Format "yyyyMMdd_HHmmss")),
    [String] $guestUsername = "Administrator",
    [String] $guestPassword = "Qwerty123",
    [switch] [bool] $runDirectly = $false,
    [ValidateSet("runReverting","runMoving","runMovingToPool","runRenameVMs","renameSnapshotOnDesk","getSnapshots","runAddToInventory","runMovingToDS")] $runCommand
)

### Code
Clear-Host

# Adding snapin
try{
    Add-PSSnapin VMWare.VimAutomation.Core -ErrorAction:SilentlyContinue
}catch{
    Write-Host "WARNING. VMWare snapin does not exists or already added..."
}

# Close previous connections
try{
    Disconnect-VIServer * -Confirm:$false -ErrorAction:SilentlyContinue
}catch{
    Write-Host "WARNING. You are not currently connected to any servers..."
}

# Base functions
function Make-PSCredentials{
    Param( $UserName, $Password )
    $PasswordSS = ConvertTo-SecureString $Password -AsPlainText -Force
    return (New-Object Management.Automation.PSCredential @($UserName, $PasswordSS))
}

function Write-Log{
    Param( $message, $type = "Information", $logFilePath = $logFilePath )
    while($type.Length -lt 12){ $type += " " }
    $currentTime = Get-Date -Format "yyyyMMdd_HHmmss"
    $logLine = "[$currentTime]`t$type`t$message"
    Write-Host $logLine
    Out-File -FilePath $logFilePath -InputObject $logLine -Append
}

function Write-LogException{
    Param( $message, $logFilePath = $logFilePath )
    Write-Log -message $message -type "Exception" -logFilePath $logFilePath
}

function Write-LogWarning{
    Param( $message, $logFilePath = $logFilePath )
    Write-Log -message $message -type "Warning" -logFilePath $logFilePath
}

# Code

if($runDirectly){
    switch($runCommand){
        "runAddToInventory" {
			Connect-VIServer -Server vcenter-spb-prm -User paragon\saakyan -Password nDds4fq2

			
			
			#$s=$h|Get-Datastore *ssd2
			$s=$h|Get-Datastore *srv1002:hdd1*
			$l=(ls $s.DatastoreBrowserPath)|sort
			$vmxList = $l|%{Get-Item -Path "$($_)\$($_.Name)*.vmx"}
			$vmxList|%{
				New-VM -Name ($_.PSParentPath.Split("\")[-1]) -VMHost $h -VMFilePath $_.DatastoreFullPath -RunAsync
			}
        }
        "renameSnapshotOnDesk" {
            Clear-Host
            Write-Host "Reverting stand... $vmArmSnapshotList"
            $oldSnapNamePrefix = "previous_"
            $newSnapNamePrefix =  "prev1ous_"
            $server = Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword
            $vmFullNameList = @($vmDomainName,$vmArmNameList,$vmTargetNameList)|%{$_.Split(",")|%{"$_-$newDeskId"}}
            $vmFullList = Get-VM -Name $vmFullNameList -ErrorAction:SilentlyContinue
            $vmFullList
            $vmFullList|%{
                $vm = $_
                $snapList = Get-Snapshot -VM $vm -Name "*$($oldSnapNamePrefix)*" -ErrorAction:SilentlyContinue
                $snapList.Name
                $snapList|%{
                    Set-Snapshot -Snapshot $_ -Name ($_.Name.Replace($oldSnapNamePrefix,$newSnapNamePrefix)) -Confirm:$false
                }
            }
        }
		"runMovingToPool" {
			Clear-Host
			$newDeskId = "xmsk"
			$vcenter = "vcenter-msk-prm"
			$esxHost = "sb611"
			
			Write-Host "Moving stand `"*-$newDeskId`" to pool..."
            $server = Connect-VIServer -Server $vcenter -User $vcenterUserName -Password $vcenterPassword
            $vmHost = Get-VMHost -Server $server -Name "$esxHost*"
            function MoveToResourcePool{
                Param( $server, $vmHost, $vm, $resourcePath )
                foreach($tmpPoolName in $resourcePath.Split("\")){
                    if(!$parentPool){ $parentPool = $vmHost }
                    $tmpPool = Get-ResourcePool -Server $server -Location $parentPool -Name $tmpPoolName
                    if(!$tmpPool){
                        $tmpPool = New-ResourcePool -Server $server -Location $parentPool -Name $tmpPoolName
                    }
                    $parentPool = $tmpPool
                }
                Move-VM -VM $vm -Destination $tmpPool -RunAsync
            }
            $vmList = Get-VM -Name "*-$newDeskId" -Server $server -Location $vmHost
            $vmList|%{
                $vmShortName = $_.Name.Replace("-$newDeskId","")
                $vmLocationTable = @{
                    "PRM-AT-??" = "Desk-$newDeskId\Targets";
                    "PRM-BT-??" = "Desk-$newDeskId\Targets";
                    "PRM-CT-??" = "Desk-$newDeskId\Targets";
                    "prm-domain" = "Desk-$newDeskId\Servers";
                    "w???wpro??en" = "Desk-$newDeskId\Arms";
                    "w???went??en" = "Desk-$newDeskId\Arms";
                    "w???sstd??en" = "Desk-$newDeskId\Arms";
                    "w???wbus??en" = "Desk-$newDeskId\Arms";
                    "w???sweb??en" = "Desk-$newDeskId\Arms";
                    "ta-*" = "Desk-$newDeskId"
                }
                $locationKey = $vmLocationTable.Keys|?{$vmShortName -like $_}
                $resourcePath = $vmLocationTable[$locationKey]
                Write-Host "Moving $_ to `"$resourcePath`"..."
                MoveToResourcePool -VM $_ -server $server -vmHost $vmHost -resourcePath $resourcePath
            }
		}
        "runMovingToDS" {
            Clear-Host
            Write-Host "Moving stand..."
            $server = Connect-VIServer -Server vcenter-dlg-prm -User paragon\saakyan	-Password nDds4fq4
            $vmHost = Get-VMHost -Server $server -Name "$esxHost*"
            $dstHost = Get-VMHost -Server $server -Name "*$esxHost*"
            $esxHostShort = @($dstHost.Name.Split("."))[0]
            $dsList = Get-Datastore -Server $server -VMHost $dstHost
            $dsList
            $vmList = Get-VM -Name "*-$newDeskId" -Server $server -Location $vmHost
            $vmList|%{$_.Name}
            
            $dsLocationTable = @{
              "PRM-AT-02" = "hdd1";
               "PRM-BT-01" = "hdd3";
				"PRM-BT-02" = "hdd2";
				"PRM-BT-03" = "hdd1";
                "PRM-BT-04" = "hdd3";
                "PRM-BT-05" = "hdd1";
                "PRM-BT-06" = "hdd2";
                "PRM-BT-10" = "hdd1";
                "PRM-BT-11" = "hdd3";
                "PRM-BT-12" = "hdd1";
                "PRM-BT-13" = "hdd2";
				"PRM-BT-14" = "hdd1";
                "PRM-BT-15" = "hdd3";
				"PRM-CT-01" = "hdd1";
                "PRM-CT-02" = "hdd2";
                "PRM-CT-03" = "hdd1";
                "PRM-CT-04" = "hdd3";
                "PRM-CT-05" = "hdd1";
                "PRM-CT-06" = "hdd2";                
                "PRM-CT-08" = "hdd1";
                "PRM-CT-12" = "hdd3";
                "PRM-CT-13" = "hdd1";
                "PRM-CT-14" = "hdd2";
                "PRM-CT-15" = "hdd1";
                "PRM-CT-16" = "hdd3";
                "PRM-CT-17" = "hdd1";
				"PRM-CT-18" = "hdd2";
              
				"prm-domain" = "hdd1";
                #"PRM-FS-$newDeskId" = "hdd3";
                "w513wpro86en" = "hdd1"; 
				"w522sstd64en" = "hdd3";
				"w522sweb86en" = "hdd2"; 
				"w602sstd86en" = "hdd1";
                "w602sstd64en" = "hdd2";
                "w602wbus86en" = "hdd3";
                "w610sstd64en" = "hdd1";
                "w611went64en" = "hdd2";
				"w620sstd64en" = "hdd3";
                "w620went64en" = "hdd2";            
                "w630sstd64en" = "hdd1";            
                "w630wpro64en" = "hdd3";     
			    "ta-*" = "hdd3"
              }
           <#   #  "ta-$esxHostShort" = "hdd1";  
            
            $vmList|%{
                $vmName = $_.Name
                $vmName.Replace("-$newDeskId","")
                $vmLocationName = ("$esxHostShort`:" + $dsLocationTable[($dsLocationTable.Keys|?{$vmName.Replace("-$newDeskId","") -like $_})])
                $dsLocation = $dsList|?{$_.Name -eq $vmLocationName}
				
                Write-Host "Moving $vmName to $dsLocation"
                #Set-VM -VM $_ -Snapshot (Get-Snapshot -VM $_ -Name @($_.ExtensionData.Snapshot.RootSnapshotList)[0].Name) -Confirm:$false
                Move-VM -VM $_ -Datastore $dsLocation #-RunAsync
			}	 #> 
				
				$vmList = Get-VM -Name "*-$newDeskId" -Server $server #-Location $vmHost
                    $vmList|%{
                        $vmName = $_.Name
                        $vmShortName = $vmName -replace "-$newDeskId$",""
                        $vmLocationKey = ($dsLocationTable.Keys|?{$vmShortName -like $_})
                        
                            $vmLocationDS = $dsLocationTable[$vmLocationKey]
                            Write-Log "Moving $vmName"
                            $vmLocationName = "$esxHostShort`:$(  )"
                            $dsLocation = $dsList|?{$_.Name -eq $vmLocationName}
                         $dsLocation = "hdd1"
                                Move-VM -Server srv405 -VM $_ -Datastore $dsLocation -RunAsync
                                Write-Log "$vmName successfullty moved to $vmLocationName ($dsLocation)"
                            }
				
				
				
				
            
        }
        "runMoving" {
            Clear-Host
            Write-Host "Moving stand..."
            $server = Connect-VIServer -Server $vcenter -User $vcenterUserName -Password $vcenterPassword
            $vmHost = Get-VMHost -Server $server -Name "$esxHost*"
            $esxHostShort = @($esxHost.Split("."))[0]
            $dsList = Get-Datastore -Server $server -VMHost $vmHost
            $dsList
            $vmList = Get-VM -Name "*-$newDeskId" -Server $server -Location $vmHost
            $vmList|%{$_.Name}
            $dsLocationTable = @{
                "PRM-AT-??" = "$esxHostShort:hdd1";
                "PRM-BT-??" = "$esxHostShort:hdd1";
                "PRM-CT-??" = "$esxHostShort:hdd3";
                "prm-domain" = "$esxHostShort:hdd1";
                #"PRM-FS-$newDeskId" = "$esxHostShort:hdd3";
                "w513wpro86en" = "$esxHostShort:ssd2";
                "w602wbus86en" = "$esxHostShort:ssd1";
                "w610sstd64en" = "$esxHostShort:ssd2";
                "w522sweb86en" = "$esxHostShort:ssd1";
                "w620went64en" = "$esxHostShort:ssd2";
                "w602sstd86en" = "$esxHostShort:ssd1";
                "w522sstd64en" = "$esxHostShort:ssd2";
                "w602sstd64en" = "$esxHostShort:ssd1";
                "w611went64en" = "$esxHostShort:ssd2"
            }
            $dsLocationTable = @{ "*" = "iscsi-obn:disk0" }
            $vmList|%{
                $vmName = $_.Name
                $vmLocationName = ($dsLocationTable[($dsLocationTable.Keys|?{$vmName.Replace("-$newDeskId","") -like $_})])
                Write-Host "Moving $vmName to $vmLocationName"
                $dsLocation = $dsList|?{$_.Name -eq $vmLocationName}
                if($dsLocation){ Move-VM -VM $_ -Datastore $dsLocation -RunAsync }
            }
        }
		"runRenameVMs" {
           # $server = Connect-VIServer -Server $vcenter -User $vcenterUserName -Password $vcenterPassword
            $server = Connect-VIServer -Server srv048 -User $esxUserName -Password $vcenterPassword
            $vmHost = Get-VMHost -Server $server -Name "$esxHost*"
            $vmList = Get-VM -Name "*-$oldDeskId" -Server $server -Location $vmHost
            $vmFullNameList = @($vmDomainName,$vmArmNameList,$vmTargetNameList)|%{$_.Split(",")|%{"$_-$oldDeskId"}}
            $vmFullList = Get-VM -Name $vmFullNameList -ErrorAction:SilentlyContinue
            $vmFullList|%{
                (Set-VM -VM $_ -Name ($_.Name -replace "-$oldDeskId","-$newDeskId") -Confirm:$false -RunAsync)|Out-Null
            }
		}
        "runReverting" {
            Clear-Host
            Write-Host "Reverting stand... $vmArmSnapshotList"
            $server = Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword
            $vmFullNameList = @($vmDomainName,$vmArmNameList,$vmTargetNameList)|%{$_.Split(",")|%{"$_-$oldDeskId"}}
            $vmFullList = Get-VM -Name $vmFullNameList -ErrorAction:SilentlyContinue
            $vmFullList
            $vmFullList|%{
                $vm = $_
                $vmArmSnapshotList|%{$_.Split(",")}|%{
                    $snap = Get-Snapshot -VM $vm -Name "previous_$_" -ErrorAction:SilentlyContinue
                    if($snap){
                        Set-VM -VM $vm -Snapshot $snap -Confirm:$false
                        while(Get-Snapshot -VM $vm -Name $_ -ErrorAction:SilentlyContinue){
                            Remove-Snapshot -Snapshot (Get-Snapshot -VM $vm -Name $_) -Confirm:$false
                        }
                        Set-Snapshot -Snapshot $snap -Name $_ -Confirm:$false
                    }
                }
                #(Set-VM -VM $_ -Name ($_.Name -replace "-$newDeskId","-$oldDeskId") -Confirm:$false)|Out-Null
            }
        }
        "getSnapshots" {
            Clear-Host
            Write-Host "Getting snapshots..."
            $server = Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword
            $vmFullList = Get-VM -Name "*-$newDeskId" -ErrorAction:SilentlyContinue
            $vmFullList|sort|%{ Write-Host "$($_.Name)`t$(($_|Get-Snapshot)|%{$_.Name})"}
        }
    }
    Write-Host "Good!"
}else{
    Write-Host "DeskRenamer.ps1 added as module."
}
