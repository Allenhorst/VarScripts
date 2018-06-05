## This script just create recovery policy. Not run. 

## Connect to the Infrastructure. If it need.
Connect-PRMServer localhost -Login administrator -Password Qwerty123

## Name of your Restore policy
$policyName = "restore_linux_machine"

##  Name of your Storage
$storageName = "My_storage"

## Name of your Agent from storage
$agentName = "l131s64-01-xx"

##  ID of catalog with your machine
$catalogId = (gi prm::storages\$storageName\$agentName).ID.Guid

## Name machine to recovery. 
$vimName = "l131s64-01-xx"

## Create your policy (DO NOT CHANGE COMPONENT MASK)
$policy = ni prm::policies\$policyName -PolicyType "Recovery" -Computers $vimName -props @{ComponentMask = 'Agent';HelpDeskTag="123"}

## Add rules (DO NOT CHANGE THIS!!!)
$ruleName = $policyName + "_BackupStorage"
ni prm::rules\$ruleName -rt "BackupStorage" -policies $policyName -props @{Storage=$storageName}

$ruleName = $policyName + "_BackupCatalog"
ni prm::rules\$ruleName -rt "BackupCatalog" -policies $policyName -props @{Catalog=$catalogId}

$ruleName = $policyName + "_VolumeProtection"
ni prm::rules\$ruleName -RuleType "VolumeProtection" -Policies $policyName