
Add-PSSnapin VMWare.VimAutomation.Core

Connect-VIServer -Server "srv384" -User autotester -Password asdF5hh

$vm = Get-VM -Name "prm-domain-64" 
$script = 'get-service | where-object {$_.Status -ne "Running" -or $_.Status -ne "Stopped"}'
$g_u = "administrator"
$g_p = "Qwerty123"
$stype = powershell
Invoke-VMScript -VM $VM -ScriptText $Script -GuestUser $g_u -GuestPassword $g_p -ToolsWaitSecs 600 -ScriptType $stype