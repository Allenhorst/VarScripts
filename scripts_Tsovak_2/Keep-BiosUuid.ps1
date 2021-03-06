function Keep-BiosUuid {
    Param (
      #  [Parameter(Mandatory,HelpMessage='VM name',ValueFromPipelineByPropertyName)]
        [string[]] $Name,
       # [Parameter(Mandatory)]
        [string] $Datacenter,
       # [Parameter(Mandatory)]
        [string] $ExportedPath
    )
    foreach ($VmName in $Name) {
        $VM = Get-VM $VmName
        $VmConfig = Copy-DatastoreItem -Destination $env:TEMP -PassThru `
        -Item "vmstore:\$Datacenter\$($VM.ExtensionData.Config.Files.VmPathName -replace '\[([^\]]+)\] ([^/]+)/(.*)','$1\$2\$3')"
        Add-Content "$ExportedPath\$VmName\$VmName.vmx" ((cat $VmConfig | sls 'uuid.bios'), 'uuid.action = "keep"')
        rm $VmConfig -Confirm:$False
    }
}

add-pssnapin VMware.VimAutomation.Core
Connect-VIServer -Server srv042 -User autotester -Password asdF5hh


$Name = "prm-ct-02-35"
$Datacenter = "Prm Production"
$ExportedPath = "C:\"

$res = Keep-BiosUuid($Name,$Datacenter, $ExportedPath)