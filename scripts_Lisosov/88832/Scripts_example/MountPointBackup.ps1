## Name of machine to backup
$computerName = "l131s64-01-xx"

## Name of storage to save backup
$storageName ="My_storage"

## Name of You policy
$policyName = "Backup_MountPoint"

## MountPoint to backup
$backupMountPoint="/mnt/D"

$computer = gi prm::computers\$computerName

## Create your policy (DO NOT CHANGE COMPONENT MASK!)
$policy = ni prm::policies\$policyName -policytype "Backup" -computers $computer -Properties @{ComponentMask="Agent";} 

$storage = gi prm::storages\$storageName

## DO NOT CHANGE THIS!
ni prm::rules\BackupStorageRule -RuleType "BackupStorage" -policies $policyName -Properties @{Storage=$storage.Name}

## DO NOT CHANGE THIS!
$mountFilter = new-object "Prm.Base.SearchFilter" 1, ([Prm.Base.SearchFilterOperator]::Equal), $backupMountPoint

## DO NOT CHANGE THIS!
ni prm::rules\VolumeProtectionRule -RuleType "VolumeProtection" -Policies $policyName -Properties @{Filter=$mountFilter}

## Submit policy
Submit-PRMPolicy($policy)