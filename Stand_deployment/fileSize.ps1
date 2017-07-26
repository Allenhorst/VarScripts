$server = Connect-VIServer srv1164 -User root -Password lpc3TAWvbW
$dsImpl = Get-Datastore -Server $server -Name "srv1164:hdd1"
$dsImpl | % {
     $ds = $_ | Get-View
     $path = ""
     $dsBrowser = Get-View $ds.Browser
     $spec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
     $spec.Details = New-Object VMware.Vim.FileQueryFlags
     $spec.Details.fileSize = $true
     $spec.Details.fileType = $true
     $vmdkQry = New-Object VMware.Vim.VmDiskFileQuery
     $spec.Query = (New-Object VMware.Vim.VmDiskFileQuery),(New-Object VMware.Vim.VmLogFileQuery)
     
     $taskMoRef = $dsBrowser.SearchDatastoreSubFolders_Task($path, $spec)
     $task = Get-View $taskMoRef
     while("running","queued" -contains $task.Info.State){
          $task.UpdateViewData("Info")
     }
     $task.Info.Result | %{
               $vmName = ([regex]::matches($_.FolderPath,"\[\w*\]\s*(\w+)"))[0].groups[1].value
               $_.File | %{
                    New-Object PSObject -Property @{
                         DSName = $ds.Name
                         VMname = $vmName
                         FileName = $_.Path
                         FileSize = $_.FileSize
                    }
               }
     }
} | Export-Csv "C:\File-report.csv" -NoTypeInformation -UseCulture

Disconnect-VIServer -Confirm:$false -Force:$true