$server = "vcenter-spb-prm"

function Write-Log{
    Param( $message )
	$type = "{0,12}" -f $type
	($message|Out-String).Split("`n")|?{$_ -ne ""}|%{
		$logLine = "[$(Get-Date -Format "yyyyMMdd_HHmmss")]`t$type`t$($_<#.Trim()#>)"
		Write-Host $message
		Out-File -FilePath "C:\ping.txt" -InputObject ($logLine + $message)  -Append
	}
}

while ($true)
{
	$res = ping $server  -n 10
	Write-Log "res"
	}