$policyName = "RecoveryPolicy2"
$storageName = "diskStorage"
$catalogId = "04a75a3c-14e4-451e-bd02-874fe23539f7"
$vimName = "w630sstd64en-07"

ni prm::policies\$policyName -PolicyType "Recovery" -Computers $vimName -props @{ComponentMask="Agent"}
(gi prm::policies\$policyName).ComponentMask = 'Agent'

$ruleName = $policyName + "BackupStorage"
ni prm::rules\$ruleName -rt "BackupStorage" -policies $policyName -props @{Storage=$storageName}

$ruleName = $policyName + "BackupCatalog"
ni prm::rules\$ruleName -rt "BackupCatalog" -policies $policyName -props @{Catalog=$catalogId}
 
[char]$driveLetter = 'E'
$filter = new-object "Prm.Base.SearchFilter" 5, ([Prm.Base.SearchFilterOperator]::Equal), $driveLetter

$ruleName = $policyName + "VolumeProtection"
ni prm::rules\$ruleName -RuleType "VolumeProtection" -Policies $policyName -Props @{Filter=$filter}

