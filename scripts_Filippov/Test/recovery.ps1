$policyName = "RecoveryPolicy"
$storageName = "DiskStorage"
$catalogId = "fa110c9f-0a17-498b-bd55-2cfc8490efa6"
$vimName = "w611went64en-07"

ni prm::policies\$policyName -PolicyType "Recovery" -Computers $vimName
(gi prm::policies\$policyName).ComponentMask = 'Agent'

$ruleName = $policyName + "BackupStorage"
ni prm::rules\$ruleName -rt "BackupStorage" -policies $policyName -props @{Storage=$storageName}

$ruleName = $policyName + "BackupCatalog"
ni prm::rules\$ruleName -rt "BackupCatalog" -policies $policyName -props @{Catalog=$catalogId}
 
[char]$driveLetter = 'G'
$filter = new-object "Prm.Common.PrmSearchFilter" 5, ([Prm.Common.PrmSearchFilterOperator]::Equal), $driveLetter
$ruleName = $policyName + "VolumeProtection"
ni prm::rules\$ruleName -RuleType "VolumeProtection" -Policies $policyName -Props @{Filter=$filter}

