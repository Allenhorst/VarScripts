#Get current dir
function Get-ScriptDirectory (){Split-Path ((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path} 
$frameworkDir = Get-ScriptDirectory

#Initiate all frameworks (log all functions)

."$frameworkDir\WindowsBase\WindowsBase.ps1"
#Get-ChildItem function:WindowsBase.*

."$frameworkDir\PRM\PRM.ps1"
#Get-ChildItem function:PRM.*

."$frameworkDir\VMware\VMware.ps1"
#Get-ChildItem function:VMware.*

."$frameworkDir\NUnit\NUnit.ps1"
#Get-ChildItem function:NUnit.*

."$frameworkDir\BaseTypes\BaseTypes.ps1"