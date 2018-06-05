function UnZip($file, $destination) 
{ 
$shell = new-object -com shell.application
$zip = $shell.NameSpace($file)
foreach($item in $zip.items())
{
# 20 stands for :  no ui + "yes to all" in all questions
$shell.Namespace($destination).copyhere($item,20)
}
} 


#file to be copied
$file = "QT_HDM.zip"
# where to store archive
$zippath = "D:\QT_HDM_NEW"
# path to files to be copied on machine
$frompath = "\\sb1129\qt_hdm" 


# creds for share
$user_share = "paragon\autotester"
$secpas = ConvertTo-SecureString -String "asdF5hh" -AsPlainText -Force
$Creds  = New-Object  -TypeName "System.Management.Automation.PSCredential" -ArgumentList $user_share, $secpas

$errorzippath = "Folder " +  $zippath + " not exist! Creating it now."




if (!(Test-Path $zippath))
	{
	Write-Output $errorzippath
	md $zippath
	}


if (!(Test-Path $zippath))
    {
        Write-Error "Target folder doens't exist even now."
        exit 1

    }



New-PSDrive -Name "T" -PSProvider "FileSystem" -Root $frompath -Credential $Creds


$itempath= "T:\"+$file

Copy-Item $itempath -Destination $zippath -Recurse

$arc = $zippath +"\" + $file
UnZip -file $arc -destination $zippath

#don't need this drive more
Remove-PSDrive -Name "T"


# remove copied archive
DEL $arc 



#modify PATH variable
$OldPath = [System.Environment]::GetEnvironmentVariable("path")
if ($OldPath | Select-String -SimpleMatch $zippath)
	{ 
		Write-Warning "Folder" + $zippath + "is already in the path"
	}
else
{
# Set the New Path
$NewPath = $OldPath+ ";" + $zippath + "\bin"

[System.Environment]::SetEnvironmentVariable("path",$NewPath, [System.EnvironmentVariableTarget]::Machine)

}