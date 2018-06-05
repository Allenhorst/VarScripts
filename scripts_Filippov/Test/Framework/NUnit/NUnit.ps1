
function NUnit.InitXML($file){
	$now = Get-Date
	$UserName = [Environment]::UserName
	$UserDomainName = [Environment]::UserDomainName
	$MachineName = [Environment]::MachineName
	$os = (Get-WmiObject Win32_OperatingSystem)
	$os_version =  ($os.caption + $os.version)
	$Culture = (Get-Culture).Name
	$UICulture = (Get-UICulture).Name
@"
<?xml version="1.0" encoding="UTF-8"?>
<test-results name="PowerShellAutomatedTest" total="0" errors="0" failures="0" not-run="0" inconclusive="0" ignored="0" skipped="0" invalid="0" date="$($now.ToString("yyyy`'-`'MM`'-`'dd"))" time="$($now.ToString("HH`':`'mm`':`'ss"))">
  <environment os-version="$os_version" platform=""  machine-name="$MachineName" user="$UserName" user-domain="$UserDomainName" />
  <culture-info current-culture="$Culture" current-uiculture="$UICulture" />
</test-results>
"@ | Out-File $file
}

function NUnit.AddTestSuite($file, $_TSName){
	$_NUResults = [xml](Get-Content $file)
	$testsuite = $_NUResults.CreateElement("test-suite")
	$testsuite.SetAttribute("type", "Test")	
	$testsuite.SetAttribute("name", $_TSName)
	$testsuite.SetAttribute("executed", $true)
	$testsuite.SetAttribute("result", "Success")
	$testsuite.SetAttribute("success", $true)
	$testsuite.SetAttribute("time", "0")
	$testsuite.SetAttribute("asserts", "0")
	$t = $_NUResults.SelectSingleNode("./test-results").AppendChild($testsuite)
	$results = $_NUResults.CreateElement("results")
	$t = $_NUResults.SelectSingleNode("//test-suite[@name='$_TSName']").AppendChild($results)
	$_NUResults.save($file)
}

function NUnit.UpdateTestSuite($_NUResults , $_TSName, $_time, $_assertscount, $_result, $_success){
	#update time
	$ts_time = $_NUResults.SelectSingleNode("//test-suite[@name='$_TSName']").GetAttribute("time")
	$_time = ([double]($ts_time) + [double]($_time))
	$_NUResults.SelectSingleNode("//test-suite[@name='$_TSName']").SetAttribute("time", $_time)
	#update assert count
	$ts_assertscount = $_NUResults.SelectSingleNode("//test-suite[@name='$_TSName']").GetAttribute("asserts")
	$_assertscount = ([double]($ts_assertscount) + [double]($_assertscount))
	$_NUResults.SelectSingleNode("//test-suite[@name='$_TSName']").SetAttribute("asserts", $_assertscount)
	if ($_result -eq "Failure"){
		$_NUResults.SelectSingleNode("//test-suite[@name='$_TSName']").SetAttribute("result", $_result)
		$_NUResults.SelectSingleNode("//test-suite[@name='$_TSName']").SetAttribute("success", "False")
	}
	return $_NUResults
}

function NUnit.UpdateCount($_NUResults, $_name){
	$r_total = $_NUResults.SelectSingleNode("./test-results").GetAttribute($_name)
	$r_total = ([int]($r_total) + 1)
	$_NUResults.SelectSingleNode("./test-results").SetAttribute($_name, $r_total)
	return $_NUResults
}

function NUnit.UpdateCountS($_NUResults, $_result){
	$_NUResults = NUnit.UpdateCount $_NUResults "total"
	if ($_result -eq "Error"){$_NUResults = NUnit.UpdateCount $_NUResults "errors"}
	if ($_result -eq "Failure"){$_NUResults = NUnit.UpdateCount $_NUResults "failures"}
	if ($_result -eq "NotRunnable"){$_NUResults = NUnit.UpdateCount $_NUResults "not-run"}
	if ($_result -eq "Inconclusive"){$_NUResults = NUnit.UpdateCount $_NUResults "inconclusive"}
	if ($_result -eq "Ignored"){$_NUResults = NUnit.UpdateCount $_NUResults "ignored"}
	if ($_result -eq "Skipped"){$_NUResults = NUnit.UpdateCount $_NUResults "skipped"}
	if ($_result -eq "Invalid"){$_NUResults = NUnit.UpdateCount $_NUResults "invalid"}
	return $_NUResults
}

function NUnit.WriteResult($file, $TestCaseCName, $TestSuiteSName, $executed = $true, $result = "Success", 
	$success = $true, $time = "0", $message = "", $stacktrace = ""){
	if(!(Test-Path $file)){ NUnit.InitXML $file}
	$_NUResults = [xml](Get-Content $file)
	if(($_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results")) -eq $null){
		NUnit.AddTestSuite $file $TestSuiteSName
		$_NUResults = [xml](Get-Content $file)
	}
	#check asserts failed
	if($global:AssertsFailedCount -gt 0){
		$stacktrace = "Asserts errors:`n$global:AssertsErrors StackTrace:`n$stacktrace"
		if($result -eq "Success"){$result = "Failure"}
	}
	#set test-case values
	$testcase = $_NUResults.CreateElement("test-case")
	$testcase.SetAttribute("name", $TestCaseCName)
	$testcase.SetAttribute("executed", $executed)
	$testcase.SetAttribute("result", $result)
	if($result -ne "NotRunnable"){
		$testcase.SetAttribute("success", $success)
		$testcase.SetAttribute("time", $time)
		$testcase.SetAttribute("asserts", $global:AssertsCount)	
		#Create test-case node
		$t = $_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results").AppendChild($testcase)
		$_NUResults = NUnit.UpdateCountS $_NUResults $result
		if($result -eq "Success"){
			#Create message node
			$_xmlmsg = $_NUResults.CreateElement("message")
			if($global:AssertsMessages -ne ""){$message = "Asserts Messages:`n$global:AssertsMessages$message"}
			$_xmlmsg.set_InnerXML("<![CDATA[$message]]>")
			$t = $_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results/test-case[@name='$TestCaseCName']").AppendChild($_xmlmsg)
			#Create stack trace node
			$_xmltack = $_NUResults.CreateElement("stack-trace")
			$_xmltack.set_InnerXML("<![CDATA[$stacktrace]]>")
			$t = $_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results/test-case[@name='$TestCaseCName']").AppendChild($_xmltack)
		}
		else{
			$_failure_node = $_NUResults.CreateElement("failure")
			$t = $_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results/test-case[@name='$TestCaseCName']").AppendChild($_failure_node)
			#Create message node
			$_xmlmsg = $_NUResults.CreateElement("message")
			if($global:AssertsMessages -ne ""){$message = "Asserts Messages:`n$global:AssertsMessages$message"}
			$_xmlmsg.set_InnerXML("<![CDATA[$message]]>")
			$t = $_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results/test-case[@name='$TestCaseCName']/failure").AppendChild($_xmlmsg)
			#Create stack trace node
			$_xmltack = $_NUResults.CreateElement("stack-trace")
			$_xmltack.set_InnerXML("<![CDATA[$stacktrace]]>")
			$t = $_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results/test-case[@name='$TestCaseCName']/failure").AppendChild($_xmltack)
		}		
	}
	else{
		$t = $_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results").AppendChild($testcase)
		$_NUResults = NUnit.UpdateCountS $_NUResults $result
		#Create reason node fore not runed test
		$_reason = $_NUResults.CreateElement("reason")
		$t = $_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results/test-case[@name='$TestCaseCName']").AppendChild($_reason)
		#Create message node
		$_xmlmsg = $_NUResults.CreateElement("message")
		$_xmlmsg.set_InnerXML("<![CDATA[Stoped after failed test]]>")
		$t = $_NUResults.SelectSingleNode("//test-suite[@name='$TestSuiteSName']/results/test-case[@name='$TestCaseCName']/reason").AppendChild($_xmlmsg)
	}	
	#Update suite counts
	$_NUResults = NUnit.UpdateTestSuite $_NUResults $TestSuiteSName $time $global:AssertsCount $result $success
	#Save xml
	$_NUResults.save($file)	
	WindowsBase.Log ("Asserts:" + $global:AssertsCount + " | Failed:" +$global:AssertsFailedCount +" | Result:" + $result + " | Time:" +$time)	
	NUnit.ResetAsserts 
}

function NUnit.Assert{ 
    Param
	(  
		[bool] $condition = $(Please specify a condition), 
		[string] $message = "Test failed."  
    ) 
    $global:AssertsCount++
	if(-not $condition) 
    {
	    $global:AssertsFailedCount++
		$message = "FAIL. $message"
		$global:AssertsErrors += ($message + "`n")
    } 
    else{
		$message = "$message"
		$global:AssertsMessages += ($message + "`n")
	}
	WindowsBase.Log ("assert:  " + $message)
} 

function NUnit.AssertEquals{
	Param
	(
		$expected = $(Please specify the expected object), 
		$actual = $(Please specify the actual object), 
		[string] $message = "Test failed."  
    )
	$global:AssertsCount++
    if(-not ($expected -eq $actual)){ 
        $global:AssertsFailedCount++
		$message = "FAIL.  Expected: $expected.  Actual: $actual.  $message" 
		$global:AssertsErrors += ($message + "`n")
    } 
    else{
		$message = ("$message " + " Expected: $expected.  Actual: $actual.")
		$global:AssertsMessages += ($message + "`n")
	}
	WindowsBase.Log ("assert:  " + $message)
}

function NUnit.ResetAsserts(){
	$global:AssertsCount = 0
	$global:AssertsErrors = ""
	$global:AssertsMessages = ""
	$global:AssertsFailedCount = 0
}
#Reset asserts on initiation Nunit framework
NUnit.ResetAsserts

function NUnit.run-test($t, $test_suite, $test_name ,$xml_path){	
	$StartTime = Get-Date
	$Error.clear()
	if($global:StopFlag -ne $true){
		if(!($t.get_Parameters().ContainsKey("Ignore"))){
			$exec = $true
			WindowsBase.Log ("======================= Start: $t =======================")
			$result="Success"	
			try{
				Write-Host ("##teamcity[progressMessage '" + $test_name + "']")
				NUnit.IfDebug $test_name
				$message = Invoke-Expression $t
			}
			catch{
				$result = "Failure"
				$stack = ($Error)
				if($t.get_Parameters().ContainsKey("StopOnError")){$global:StopFlag = $true}
			}	
			#sleep 1
			if(($t.get_Parameters().ContainsKey("StopOnError")) -and ($global:AssertsFailedCount -gt 0)){$global:StopFlag = $true}
		}
		else{
			WindowsBase.Log "Ignored test: $t"
			$result = "Ignored"
			$exec = $false
		}
	}
	Else{
		$tf = @("TestFixtureSetup", "TestFixtureTearsDown")
		if(!($tf -contains $test_name)){
			WindowsBase.Log "Ignored test: $t"
			$result = "NotRunnable"
			$exec = $false
		}
		else{
			$exec = $true
			WindowsBase.Log "Start: $t"
			$result="Success"	
			try{
				NUnit.IfDebug $test_name
				$message = Invoke-Expression $t
			}
			catch{
				$result = "Failure"
				$stack = ($Error)
				if($t.get_Parameters().ContainsKey("StopOnError")){$global:StopFlag = $true}
			}
		}
	}
	$rt = (Get-Date) - $StartTime
	$Runtime = [double]([string]::format("{0}.{1}", $rt.Seconds,$rt.Milliseconds))+
		[double]([string]::format("{0}", $rt.Minutes))*60 +
		[double]([string]::format("{0}", $rt.Hours))*60*60 +
		[double]([string]::format("{0}", $rt.Days))*60*60*24
	#NUnit.WriteResult $xml_path "$t" $test_suite -time $Runtime -result $result -executed $exec -message ("Test Step: $t `n" + $message) -stacktrace $stack
	NUnit.WriteResult $xml_path "$t" $test_suite -time $Runtime -result $result -executed $exec -message ("Test Step: $t") -stacktrace $stack
	WindowsBase.Log ("======================= Finish: $t =======================`n")
}

function NUnit.IfDebug{
	Param
	(
		[string] $testName
	)
	if($global:DebugStep -eq $testName){
		$OUTPUT = [System.Windows.Forms.MessageBox]::Show(("We are proceeding with next step: " + $testName + ""), ("Stop test on " + $testName + " step" ), 4)
		if ($OUTPUT -eq "YES" ) 
		{
			WindowsBase.Log "[Debug] Continue test after debug step"
		} 
		else 
		{
			throw "[Debug] Stop test execution on debug step"
		}
	}
}

function NUnit.Test($tests, $xml_path){
	foreach($t in $tests){
		$_ts = $t.split(".")
		$test_suite = $_ts[$_ts.length-2]
		$test_name = $_ts[$_ts.length-1]		
		NUnit.run-test $t $test_suite $test_name $xml_path
	}
}

function NUnit.RunAllTests($xml_path){
	$test_path = ((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path
	$_tests = Get-ChildItem function:*Tests.*
	#=======================================================================
	Write-Host ""
	Write-Host "====================================== Tests ======================================"
	foreach($f in $_tests) {write-host ($f.name + ":	" + $f.Parameters.Keys + "")}
	Write-Host "====================================== Tests ======================================"
	Write-Host ""
	#=======================================================================
	if($_tests -eq $null){
		WindowsBase.Log "No tests"
		return
	}
	$global:StopFlag = $false
	#Find test environment functions
	NUnit.GetEnvFunctions $_tests
	#Test Suite Setup
	NUnit.TestFixtureSetup $xml_path
	foreach($t in $_tests){
		$_ts = $t.Name.split(".")
		$test_suite = $_ts[$_ts.length-2]
		$test_name = $_ts[$_ts.length-1]
		
		$tf = @("TestFixtureSetup", "TestFixtureTearsDown", "Setup", "TearsDown")
		if(!($tf -contains $test_name)){
			#Setup Test
			NUnit.Setup
			#Run Test
			NUnit.run-test $t $test_suite $test_name $xml_path
			#Test tears down
			NUnit.TearsDown
		}
	}
	#Test Suite tears down
	NUnit.TestFixtureTearsDown $xml_path
}

function NUnit.GetEnvFunctions($_tests){
	foreach($t in $_tests){
		$_ts = $t.Name.split(".")
		$test_name = $_ts[$_ts.length-1]
		If($test_name -eq "TestFixtureSetup"){$global:TestFixtureSetup = $t}
		If($test_name -eq "TestFixtureTearsDown"){$global:TestFixtureTearsDown = $t}
		If($test_name -eq "Setup"){$global:Setup = $t}
		If($test_name -eq "TearsDown"){$global:TearsDown = $t}
	}
	#=======================================================================
	Write-Host ""
	Write-Host "============================== environment functions =============================="
	$global:TestFixtureSetup
	$global:TestFixtureTearsDown
	$global:Setup
	$global:TearsDown
	Write-Host "============================== environment functions =============================="
	Write-Host ""
	Write-Host ""
	#=======================================================================	
}

function NUnit.TestFixtureSetup($xml_path){
	if($global:TestFixtureSetup -ne $null){
		$_ts = $global:TestFixtureSetup.Name.split(".")
		$test_suite = $_ts[$_ts.length-2]
		$test_name = $_ts[$_ts.length-1]
		NUnit.run-test $global:TestFixtureSetup $test_suite $test_name $xml_path
	}
}

function NUnit.TestFixtureTearsDown($xml_path){
	if($global:TestFixtureTearsDown -ne $null){
		$_ts = $global:TestFixtureTearsDown.Name.split(".")
		$test_suite = $_ts[$_ts.length-2]
		$test_name = $_ts[$_ts.length-1]
		NUnit.run-test $global:TestFixtureTearsDown $test_suite $test_name $xml_path
	}
}

function NUnit.Setup(){
	if($global:Setup -ne $null){
		WindowsBase.Log  (Invoke-Expression $global:Setup)
	}
}

function NUnit.TearsDown(){
	if($global:TearsDown -ne $null){
		WindowsBase.Log  (Invoke-Expression $global:TearsDown)
	}
}
