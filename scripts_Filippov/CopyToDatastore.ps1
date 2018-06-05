    $VServer | Add-Member -MemberType ScriptMethod -Name CopyFileToDatastore -Value {
        Param
        (
            [String]  $sourcePath,
            [String]  $datastoreName,
            [String]  $targetFolder,
            [Boolean] $recurse = $true
        )
        
        $Error.Clear()
        $isCopyToDatastoreFine = $false
        $this.Log("Try to copy [$sourcePath] to [$datastoreName $targetFolder]")
        if($datastoreName){
            if($targetFolder){
                $this.Connect()
                try{
                    $datastore = Get-DataStore $datastoreName
                    if($datastore.Name -eq $datastoreName){
                        $isCopyToDatastoreFine = $true
                        $psDrive = New-PSDrive -Location $datastore -Name ds -PSProvider VimDatastore -Root "\"
                        if(-not (test-path "ds:\$targetFolder")){
                            mkdir "ds:\$targetFolder" | Out-Null
                        }
                        if($recurse){
                            Copy-DatastoreItem -Item $sourcePath -Destination "ds:\$targetFolder\" -Recurse -Force -Confirm:$false | Out-Null
                        }
                        else{
                            Copy-DatastoreItem -Item $sourcePath -Destination "ds:\$targetFolder\" -Force -Confirm:$false  | Out-Null
                        }
                        Remove-PSDrive $psDrive -Confirm:$false -Force:$true | Out-Null
                    }
                }
                catch{ $this.Log("Errors occurred:`n" + $Error) }
                $this.Disconnect()
            }
        }
        if($Error){    $isCopyToDatastoreFine = $false }
        $this.Log("isCopyToDatastoreFine = $isCopyToDatastoreFine")
    }
