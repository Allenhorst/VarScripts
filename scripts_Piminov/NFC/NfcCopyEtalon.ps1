$srcSuffix = "-xx"
$dstSuffix = "-xfre"

# $vmNames = "w100sstd64en,w100went64en,w100went86en,w522sstd64en,w602sstd64en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630went86en,prm-ct-01,prm-ct-02,prm-ct-04,prm-ct-05,prm-ct-09,prm-ct-14,prm-ct-16,prm-ct-18,prm-ct-19,PRM-AT-01,PRM-AT-02,prm-bt-01,prm-bt-02,prm-bt-04,prm-bt-14,prm-bt-15,prm-bt-16,prm-bt-17,prm-bt-18,prm-bt-19,prm-bt-20,prm-bt-21,prm-bt-22,prm-bt-23,prm-domain,c7s64-01,l131s64-00,u1404s64,l131s64,w630s64-01,ta-srv"
# $vmNames = "w100sstd64en,w100went64en,w630sstd64en,w630went64en,prm-ct-18,prm-ct-19,u1404s64,l131s64,w630sstd64hv,sql-2012"
$vmNames = "w100sstd64en,w100went64en,w630sstd64en,w630went64en,prm-ct-18,prm-ct-20,u1404s64,l131s64,w630sstd64hv,sql-2012,sql-2016,ta-srv"
$vmList = $vmNames.Split(",")

foreach ($vmName in $vmList)
{
    $vmNameSrc = $vmName + $srcSuffix
    $vmNameDst = $vmName + $dstSuffix
    Prm.Utilities.VmCopyTool.Cli.exe deploy --server "vcenter-dlg-prm" --user "paragon\autotester" --password "asdF5hh" --vm-name $vmNameSrc --dest-name $vmNameDst --dest-datastore "srv823:hdd2" --dest-server "vcenter-fre-prm" --dest-server-user "paragon\autotester" --dest-server-password "asdF5hh" --rp-name "Desk-xfre-ETALON" --last-snapshot --copy-bios
}