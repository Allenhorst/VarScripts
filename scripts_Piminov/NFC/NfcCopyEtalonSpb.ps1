$srcSuffix = "-xx"
$dstSuffix = "-xspb"

# $vmNames = "w100sstd64en,w100went64en,w630sstd64en,w630went64en,prm-ct-18,prm-ct-20,u1404s64,l131s64,w630sstd64hv,sql-2012,sql-2016,ta-srv"
$vmNames = "w630sstd64en"
$vmList = $vmNames.Split(",")

foreach ($vmName in $vmList)
{
    $vmNameSrc = $vmName + $srcSuffix
    $vmNameDst = $vmName + $dstSuffix
    Prm.Utilities.VmCopyTool.exe deploy --server "vcenter-dlg-prm" --user "paragon\autotester" --password "asdF5hh" --vm-name $vmNameSrc --dest-name $vmNameDst --dest-datastore "srv047:hdd3" --dest-server "vcenter-spb-prm" --dest-server-user "paragon\autotester" --dest-server-password "asdF5hh" --rp-name "Desk-xspb-ETALON" --last-snapshot --copy-bios
}