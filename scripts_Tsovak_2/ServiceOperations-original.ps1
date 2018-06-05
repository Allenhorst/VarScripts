### Code
Clear-Host

# Adding snapin
try{
    Add-PSSnapin VMWare.VimAutomation.Core -ErrorAction:SilentlyContinue
}catch{
    Write-Log "WARNING. VMWare snapin does not exists or already added..."
}

# Close previous connections
try{
    Write-Host "Clean all active connections..."
    Disconnect-VIServer * -Confirm:$false -ErrorAction:SilentlyContinue
}catch{
    Write-Log "WARNING. You are not currently connected to any servers..."
}

# Base functions
function Make-PSCredentials{
    Param( $UserName, $Password )
    $PasswordSS = ConvertTo-SecureString $Password -AsPlainText -Force
    return (New-Object Management.Automation.PSCredential @($UserName, $PasswordSS))
}

# Code
 <#
function Add-DeskToInventory{
   <#
    .SYNOPSIS
		Add desk from datastore to inventory
    .INPUTS
		None. You cannot pipe objects to Add-Extension.
    .PARAMETER vcenter
		Specified VCenter where you wont to add VirtualMachines.
    .PARAMETER esx
		Specified ESX(VMHost) where you wont to add VirtualMachines.
    .PARAMETER deskId
		Specified desk identifier of that will be added to inventory
    .PARAMETER folderDeskId
		Specified root folder's suffix on datastore where located VMX-files
		EX. For vmx file: "[sb447:hdd1] PRM-AT-01-38\PRM-AT-01-48.vmx" :	$folderDeskId = "38"
    .PARAMETER vmxDeskId
		Specified suffix of VMX-file name
		EX. For vmx file: "[sb447:hdd1] PRM-AT-01-38\PRM-AT-01-48.vmx" :	$vmxDeskId = "48"
	.EXAMPLE
		PS> Add-DeskToInventory -vcenter "vcenter-fre-prm" -esx "srv813.paragon-software.com" -datastoreName "iscsi-fre:disk0" -deskId "13"
    

	Param(
		[Parameter(Mandatory=$true)] [String] $vcenter = "vcenter-dlg-prm",
		[Parameter(Mandatory=$true)] [String] $esxName = "srv1107.paragon-software.com",
		[Parameter(Mandatory=$true)] [String] $datastoreName = "iscsi-fre:disk0",
		[Parameter(Mandatory=$true)] [String] $newDeskId = "60",
		[Parameter(Mandatory=$true)] [String] $iscsiDeskId = "60",
		[String] $vcenterUserName = "paragon\autotester",
		[String] $vcenterPassword = "asdF5hh",
		[String] $esxUserName = "autotester",
		[String] $esxPassword = "asdF5hh",
		[String] $folderDeskId = $iscsiDeskId,
		[String] $vmxDeskId = $folderDeskId
	)
	try{
		$server = Connect-VIServer -Server $vcenter -User $vcenterUserName -Password $vcenterPassword
		try{
			$vmHost = Get-VMHost -Server $server -Name "$esxName"
			$esx = Connect-VIServer -Server $vmHost.Name -User $esxUserName -Password $esxPassword
			try{
				$ds = $vmHost|Get-Datastore -Server $server -Name $datastoreName
				$vmOnDSList = (ls $ds.DatastoreBrowserPath)|sort
                Write-Log "Founded folders on $ds`: `"$vmOnDSList`""
				try{
					$vmOnDSList|%{
						$vmShortName = $_.Name -replace "-$folderDeskId$",""
						$vmxFileName = "$vmShortName`-$vmxDeskId`.vmx"
						$vmxFilePath = "$($_.DatastoreFullPath)\$vmxFileName"
						$vmName = "$vmShortName`-$newDeskId"
						if(!(Get-VM -Server $server -Name $vmName -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue)){
							if(New-VM -Server $server -Name $vmName -VMHost $vmHost -VMFilePath $vmxFilePath){ #-RunAsync
								Write-Log "$vmName successfully added"
							}else{
								if(New-VM -Server $esx -Name $vmName -VMFilePath $vmxFilePath){
									Write-Log "$vmName added via esx"
								}else{
									Write-Log "$vmName not added!"
								}
							}
						}else{
							Write-Log "$vmName already exists"
						}
					}
				}catch{
					throw $_
				}
			}catch{
				throw $_
			}
		}catch{
			throw $_
		}
	}catch{
		throw $_
	}
}
#>
function Move-DeskToDatastore{
    <#
    .SYNOPSIS
		Move Desk's VMs from VCenter to specified datastore on ESX
    .INPUTS
		None. You cannot pipe objects to Add-Extension.
    .PARAMETER vcenter
		Specified VCenter where you wont to add VirtualMachines.
    .PARAMETER esx
		Specified ESX(VMHost) where you wont to add VirtualMachines.
    .PARAMETER deskId
		Specified identifier of desk which will be moved to datastore
    .PARAMETER datastoreName
		Specified datastoreName
    .PARAMETER vmxDeskId
		Specified suffix of VMX-file name
    .PARAMETER dsLocationTable - hashtable if null then used default value from (EX.)
        EX. $dsLocationTable = @{
                "PRM-AT-??" = "sb447:hdd1";
                "PRM-BT-??" = "sb447:hdd1";
                "PRM-CT-??" = "sb447:hdd2";
                "prm-domain" = "sb447:hdd1";
                "w513wpro86en" = "sb447:ssd2";
                "w602wbus86en" = "sb447:ssd1";
                "w610sstd64en" = "sb447:ssd2";
                "w522sweb86en" = "sb447:ssd1";
                "w620went64en" = "sb447:ssd2";
                "w602sstd86en" = "sb447:ssd1";
                "w522sstd64en" = "sb447:ssd2";
                "w602sstd64en" = "sb447:ssd1";
                "w611went64en" = "sb447:ssd2"
            }
	.EXAMPLE
		PS> Move-DeskToDatastore -vcenter "vcenter-fre-prm" -esx "srv813.paragon-software.com" -datastoreName "iscsi-fre:disk0" -deskId "13"
    #>

    Param(
		[Parameter(Mandatory=$true)] [String] $vcenter = "vcenter-dlg-prm",
		[Parameter(Mandatory=$true)] [String] $esx = "srv1107.paragon-software.com",
		[Parameter(Mandatory=$true)] [String] $deskId = "60",
		[String] $vcenterUserName = "paragon\autotester",
		[String] $vcenterPassword = "asdF5hh",
		[String] $esxUserName = "autotester",
		[String] $esxPassword = "asdF5hh",
        $dsLocationTable = $null
        #$dsLocationTable = @{ "*" = "iscsi-obn:disk0" }
    )
    try{
        $server = Connect-VIServer -Server $vcenter -User $vcenterUserName -Password $vcenterPassword
        try{
            $vmHost = Get-VMHost -Server $server -Name "$esx*"
            $esxHostShort = @($esx.Split("."))[0]
            try{
                $dsList = Get-Datastore -Server $server -VMHost $vmHost
                if(!$dsLocationTable){
                    $dsLocationTable = @{
                    <#    "PRM-AT-??" = "hdd1";
                        "PRM-BT-??" = "hdd1";
                        "PRM-CT-??" = "hdd2";
                        "prm-domain" = "hdd1";
                        #"PRM-FS-$newDeskId" = "hdd2";
                        "w513wpro86en" = "ssd2";
                        "w602wbus86en" = "ssd1";
                        "w610sstd64en" = "ssd2";
                        "w522sweb86en" = "ssd1";
                        "w620went64en" = "ssd2";
                        "w602sstd86en" = "ssd1";
                        "w522sstd64en" = "ssd2";
                        "w602sstd64en" = "ssd1";
                        "w611went64en" = "ssd2"
                        #>
                        
                        
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
                }
                try{
                    $vmList = Get-VM -Name "*-$deskId" -Server $server #-Location $vmHost
                    $vmList|%{
                        $vmName = $_.Name
                        $vmShortName = $vmName -replace "-$deskId$",""
                        $vmLocationKey = ($dsLocationTable.Keys|?{$vmShortName -like $_})
                        if($vmLocationKey){
                            $vmLocationDS = $dsLocationTable[$vmLocationKey]
                            Write-Log "Moving $vmName"
                            $vmLocationName = "$esxHostShort`:$(  )"
                            $dsLocation = $dsList|?{$_.Name -eq $vmLocationName}
                            if($dsLocation){
                                Move-VM -Server srv405 -VM $_ -Datastore $dsLocation -RunAsync
                                Write-Log "$vmName successfullty moved to $vmLocationName ($dsLocation)"
                            }
                        }else{
                            Write-Log "Skip moving $vmName"
                        }
                    }
                }catch{
                    throw $_
                }
            }catch{
				throw $_
            }
        }catch{
			throw $_
        }
    }catch{
		throw $_
    }
}

$res = Move-DeskToDatastore
Write-Host "ServiceOpeartions.ps1 added as module."
