function TestWMI($computer, $user, $pass){
    Write-Host $computer, $user, $pass "WMI: `t" -NoNewline
    $t = $null
    $user = "$computer\$user"
    $pass = ConvertTo-SecureString -String $pass -AsPlainText -Force
    $t = gwmi win32_bios -ComputerName "$computer" -Credential (new-object -typename System.Management.Automation.PSCredential -argumentlist $user,$pass) -ErrorAction SilentlyContinue 
    #Clear-Host
    Write-Host ($t -ne $null)
}

$agentId = "-18"
$vmList = @("w513wpro86en",
            "w522sstd64en",
            "w522sweb86en",
            "w602sstd64en",
            "w602sstd86en",
            "w602wbus86en",
            "w610sstd64en",
            "w611went64en",
            "w620went64en",
			"w610sstd64en",
			"w630wpro64en",
			"prm-ct-18")

#TestWMI "pcName" "Administrator" "Qwerty123"   
while ($true){   
TestWMI ($vmList[9]+$agentId) "Administrator" "Qwerty123"
TestWMI ($vmList[9]+$agentId) "Administrator" "Qwerty123"}
<#TestWMI ($vmList[1]+$agentId) "Administrator" "Qwerty123"
TestWMI ($vmList[2]+$agentId) "Administrator" "Qwerty123"
TestWMI ($vmList[3]+$agentId) "Administrator" "Qwerty123"
TestWMI ($vmList[4]+$agentId) "Administrator" "Qwerty123"
TestWMI ($vmList[5]+$agentId) "Administrator" "Qwerty123"
TestWMI ($vmList[6]+$agentId) "Administrator" "Qwerty123"
TestWMI ($vmList[7]+$agentId) "Administrator" "Qwerty123"
TestWMI ($vmList[8]+$agentId) "Administrator" "Qwerty123"

#>
