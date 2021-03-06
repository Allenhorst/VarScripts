cls
function Get-ScriptDirectory (){Split-Path ((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path} 
$cdir = Get-ScriptDirectory




. "C:\svn\trunk autotests\TestAgentScripts\TeamCityClient.ps1"


$tc = Create-TeamCityClient

# extend TeamCityClient

$tc | Add-Member -MemberType ScriptMethod -Name "GetBuildsXmlFromDateAll" -Value{
	Param
	(
		[string] $buildTypeId,
		[DateTime] $date,
		[string] $timezone
	)
	$d = Get-Date
	$BaseUtcOffset = [TimeZoneInfo]::Local.BaseUtcOffset
	
	#$d.ToString("yyyyMMddTHHmmss")
	#000000-0000
	#000000%2B0000   + => %2B
	$timezone = $timezone + "00"
	$timezone = $timezone.Replace("+","%2B")
	$url = "/httpAuth/app/rest/builds/?locator=buildType:" + $buildTypeId + ",sinceDate:" + `
	$date.ToString("yyyyMMddT") + "000000" + $timezone + ",branch:default:any,personal:any,canceled:any"
	
	$str = $this.TCGetRequest($url)
	$builds = [xml] $str
	return $builds.builds.build
}

$tc | Add-Member -MemberType ScriptMethod -Name "GetProjectsBuildsCash" -Value{
	Param
	(
		[string] $projectId,
		[DateTime] $date,
		[string] $timezone	
	)
	$buildTypeNodes = $this.GetProjectConfigurations($projectId, $false, $true)
	$configurationsCash = @{} 
	foreach($bt in $buildTypeNodes){
		$builds = $this.GetBuildsXmlFromDateAll($bt.id, $date, $timezone)
		$buildResultList = @()
		Write-host ($bt.name +"  " + $builds.count)		
		if($builds.count -gt 0){
			$buildsCash = @()
			foreach($build in $builds){
				[array]$buildsCash += $build
			}
			$configurationsCash.Add($bt.id, [array]$buildsCash)
		}
		elseif($builds.id){
			$configurationsCash.Add($bt.id, $builds)
		}
		else{
			Write-Host $bt
		}
	}
	return $configurationsCash
}

$tc | Add-Member -MemberType ScriptMethod -Name "GetProjectsBuildInfo" -Value{
	Param
	(
		$build	
	)
	$status =  $build.status
	$number = $build.number
	$startVersion = $number.IndexOf("(") +1
	$prmVersion = ""
	if($startVersion -gt 0){
		$endVersion = $number.IndexOf(")")
		$prmVersion = $number.Substring($startVersion, $endVersion - $startVersion)
	}
	$buildXml = $this.GetBuildXml($build.id)
	$name = $buildXml.build.buildType.Name
	$startDateString = $buildXml.build.startDate
	$startDateString = $startDateString.Substring(0,($startDateString.Length-5))
	$startDate = [string]([datetime]::ParseExact($startDateString, "yyyyMMddTHHmmss", $null)).ToString("dd.MM.yyyy hh:mm:ss")
	$finishDateString = $buildXml.build.finishDate
	$finishDateString = $finishDateString.Substring(0,($finishDateString.Length-5))
	$finishDate = [string]([datetime]::ParseExact($finishDateString, "yyyyMMddTHHmmss", $null)).ToString("dd.MM.yyyy hh:mm:ss")
	$agentName = $buildXml.build.agent.name
	$agentId = $buildXml.build.agent.id
	$webUrl = $buildXml.build.webUrl
	$statusText = $buildXml.build.statusText
	
	$projectName = $buildXml.build.buildType.projectName
	$projectId = $buildXml.build.buildType.projectId
	$ispersonal = $buildXml.build.personal
	$triggeredDetails = $buildXml.build.triggered.type
	$user = ""
	if($buildXml.build.triggered.user){
		$user = $buildXml.build.triggered.user.username + ": " + $buildXml.build.triggered.user.name
	}
	
	$bresult = New-Object psObject -Property @{'Name'=$name;'Id'=$build.id;'Status'=$status; `
		'Number'=$number;'PrmVersion'=$prmVersion;'startDate'=$startDate; 'finishDate'=$finishDate;'agentName'=$agentName;`
		'agentId'=$agentId;'webUrl'=$webUrl; 'statusText'=$statusText;'ProjectName'=$projectName;'ProjectId'=$projectId;
		'personal'=$ispersonal;'TriggeredDetails'=$triggeredDetails;'User'=$user;}		
	if ($buildXml.build.comment){
		$commentUser = $buildXml.build.comment.user.username
		$commentText = $buildXml.build.comment.text
		$commentText = $commentText.Replace("`r"," ")
		$commentText = $commentText.Replace("`n"," ")
		$commentText = $commentText.Replace("	"," ")
		$bresult `
			| Add-Member -MemberType NoteProperty -Name commentUser -Value $commentUser -PassThru `
			| Add-Member -MemberType NoteProperty -Name commentText -Value $commentText  
	}
	
	if ($buildXml.SelectNodes("//build/artifact-dependencies/build").count -ge 0){
		$dependencyText = ""
		foreach($dependency in $buildXml.SelectNodes("//build/artifact-dependencies/build")){
			$dependencyText += ($dependency.buildTypeId + ":" + $dependency.number + " ")
		}
		$bresult `
			| Add-Member -MemberType NoteProperty -Name dependency -Value $dependencyText 
	}
	if ($buildXml.SelectSingleNode("//property[@name='branch']")){
		$branchNode = ($buildXml.SelectSingleNode("//property[@name='branch']"))
		$branch = $branchNode.value
		$bresult `
			| Add-Member -MemberType NoteProperty -Name branch -Value $branch 
	}
	return $bresult
}

$tc | Add-Member -MemberType ScriptMethod -Name "GetProjectsBuildsInfo" -Value{
	Param
	(
		[string] $projectId,
		[DateTime] $date,
		[string] $timezone	
	)
	$configurationsCash = $this.GetProjectsBuildsCash($projectId, $date, $timezone)
	$configurations = @{} 	
	foreach($bt in $configurationsCash.Keys){
		$buildResultList = @()
		foreach($build in $configurationsCash[$bt]){
			try {
				$buildResultList += $this.GetProjectsBuildInfo($build)
			}
			catch{ }
		}
		if($buildResultList -ne @()){
			$configurations.Add($bt, $buildResultList)
		}
	}
	return $configurations
}

$tc | Add-Member -MemberType ScriptMethod -Name "GetProjects" -Value{
	Param
	(
		[String] $tcUser = "adacc",
		[String] $tcPass = "jd7gowuX",
		[String] $tcUrl = "vmsk-tc-prm.paragon-software.com"		
	)
	$url = "/httpAuth/app/rest/projects/"
	$str =  $this.TCGetRequest($url)
	return [xml] $str

}


function Clean-FormCode{
	Param
	(
		[string] $path
	)
	$t =  [system.IO.File]::ReadAllText($path)
	If($t.IndexOf("#----------------------------------------------") -gt 0){
		$start = $t.IndexOf("#region Import the Assemblies")-1
		$len = $t.IndexOf("#----------------------------------------------") - $start
		$f = $t.Substring($start, $len)
		
		$start = $t.IndexOf("#region Generated Form Code") - 1
		$len = $t.IndexOf("#Save the initial state of the form") - $start
		$f += $t.Substring($start, $len)
		$f += "`$form1.WindowState = `$InitialFormWindowState"
		$f = $f.replace("#----------------------------------------------", "")
		$f | Out-File -FilePath $path
	}
}

function Load-Form{
	Param
	(
		[string] $path
	)
	Clean-FormCode $path
	$t = [system.IO.File]::ReadAllText($path)
	Invoke-Expression $t
	# map objects
	$start = $t.IndexOf("#region Generated Form Objects") + 32
	$len = $t.IndexOf("#endregion Generated Form Objects") - $start - 2
	$f = $t.Substring($start, $len)
	$f = $f.Split("`n")
	$_form = $form1
	$f | % { 
		$name = $_.Substring(1, ($_.IndexOf(" ") - 1))
		If($name -ne "form1"){
			$obj = Invoke-Expression ("`$" + $name)
			$_form | Add-Member -MemberType:NoteProperty -Name $name -Value $obj -PassThru | Out-Null
		}
	}
	return $_form
}

$ProjectReport = Load-Form "$cdir\ProjectReport-Form.ps1"
$reportCash

function LoadReport{
	Param
	(
		$project,
		$showGrid,
		$date,
		$timezone,
		$printReport = $true,
		$customColumns = $false
	)
	$ProjectReport.richTextBox1.Text = ""
	Start-Sleep -Milliseconds 300
	$ProjectReport.statusBar2.Text = "Loading..."
	$r = $tc.GetProjectsBuildsInfo($project, $date, $timezone)
	$reportCash = $r
	[array]$keys = $r.Keys
	if($keys.count -gt 0){
		$propertyList = "Id,Number,PrmVersion,startDate,finishDate,Status,Name,commentUser,commentText,dependency," + `
			"branch,personal,TriggeredDetails,User,ProjectName,ProjectId,agentName,agentId,webUrl"
		If($customColumns){$propertyList = "PrmVersion,Name,ProjectName,commentText,commentUser,Status,personal,branch "}
		$propertyList = $propertyList.Split(",")
		if($printReport){
			UpdateBuildInfo $r $propertyList
		}
		if($showGrid){
			$rr = @()
			foreach($key in $keys){
				$rr += $r[$key]
			}
			$rr |Select-Object -Property $propertyList | Out-GridView -Title ("Execution Report: " + $project)
		}
	}
	else{
		[System.Windows.Forms.MessageBox]::Show("No results for this project!") 
	}
	$ProjectReport.statusBar2.Text = "ok."
}

function UpdateBuildInfo{
	Param
	(
		$data,
		$propertyList
	)
	[array]$keys = $data.Keys
	$keys = $keys | Sort-Object
	$rr = @()
	foreach($key in $keys){
		$rr += $data[$key]
	}
	$tabbed = ""
	$rr |% {
		foreach($property in $propertyList){
			$tabbed += ($_.$property +"	")
		}
		$tabbed +=  "`r`n"
	}
	$ProjectReport.richTextBox1.Text = $tabbed
}

function PrintReport{

}

function LoadProjectList{
	$projectsXml = $tc.GetProjects()
	$ProjectReport.comboBox1.Items.Clear()
	$i = 0
	foreach($project in $projectsXml.projects.project){
		If($project.name -ne "<Root project>"){
			$ProjectReport.comboBox1.Items.Add($project.id) |Out-Null
		}
	}
}



# ↺ ↻

$ProjectReport.comboBox2.SelectedIndex = 16

$ProjectReport.button1.add_Click({
	LoadProjectList
}) 

$ProjectReport.button2.add_Click({
	$projectsXml = $tc.GetProjects()
	$projectId = $null
	foreach($project in $projectsXml.projects.project){
		If($project.id -eq $ProjectReport.comboBox1.SelectedItem){
			$projectId = $project.id
		}
	}	
	If($projectId -ne $null){
		$timezone = $ProjectReport.comboBox2.SelectedItem
		$date = $ProjectReport.dateTimePicker1.Value
		LoadReport $projectId $ProjectReport.checkBox1.Checked $date $timezone 
	}
	else{
		[System.Windows.Forms.MessageBox]::Show("No selected project!") 
	}
}) 

$ProjectReport.button3.add_Click({
	$ProjectReport.richTextBox1.Text = ""
	Start-Sleep -Milliseconds 300
	$ProjectReport.statusBar2.Text = "Loading..."
	$projectsXml = $tc.GetProjects()
	$projectId = $null
	foreach($project in $projectsXml.projects.project){
		If($project.id -eq $ProjectReport.comboBox1.SelectedItem){
			$projectId = $project.id
		}
	}
	$buildTypeNodes = $tc.GetProjectConfigurations($projectId, $false, $true)
	$selected = ""
	$selected += "select multiple='true' display='normal' "
	[int] $btId = 1
	$buildTypeNodesForSpec = $buildTypeNodes | Sort-Object -Descending:$false -Property "name"
	$filtered = ""
	foreach($bt in $buildTypeNodesForSpec){	
		
		If(($bt.name.Substring(0,2) -ne "44") -and ($bt.name.Substring(0,1) -ne "9") -and ($bt.name.Substring(0,3) -ne "SQL") -and ($bt.name.Substring(0,1) -ne "3")){
			$ProjectReport.richTextBox1.Text += ($bt.name + " => " + $bt.id + "`n")
			#label_301='301 SMOKE Main with SDK' data_301='Prm_Tests_Sdknewfn_301smokeMainWithSdk'
			$btIdString = "{0:D3}" -f $btId
			$selected +=(" label_" + $btIdString + "='" + $bt.name + "' data_" + $btIdString + "='" + $bt.id + "'"  )
			$btId++
		}else{
			$filtered +=  $bt.name + "   "
		}
	}
	$ProjectReport.richTextBox1.Text += "`n"
	$ProjectReport.richTextBox1.Text += $selected
	$ProjectReport.richTextBox1.Text += "`n`n`nFiltered:   "
	$ProjectReport.richTextBox1.Text += $filtered
	$ProjectReport.statusBar2.Text = "ok."
})


$ProjectReport.button4.add_Click({
	$timezone = $ProjectReport.comboBox2.SelectedItem
	$date = [DateTime]::Today
	$date = $date.AddDays(-1*([int]::Parse($ProjectReport.textBox1.Text)))
	LoadReport "Prm_Tests" $true $date $timezone $false $true
})

$ProjectReport.button5.add_Click({
	$timezone = $ProjectReport.comboBox2.SelectedItem
	$date = $ProjectReport.dateTimePicker1.Value
	$date = $date.AddDays(-1*([int]::Parse($ProjectReport.textBox1.Text)))
	LoadReport "ReleaseBranches_ProductionPrmR37_Tests" $true $date $timezone $false $true
#	$ccash = $tc.GetProjectsBuildsCash("Prm_Tests", $date, $timezone)
})

$ProjectReport.button6.add_Click({
	$timezone = $ProjectReport.comboBox2.SelectedItem
	$date = $ProjectReport.dateTimePicker1.Value
	$date = $date.AddDays(-1*([int]::Parse($ProjectReport.textBox1.Text)))
	LoadReport "ProductionPrmR47_Tests" $true $date $timezone $false $true
#	$ccash = $tc.GetProjectsBuildsCash("Prm_Tests", $date, $timezone)
})

LoadProjectList
$ProjectReport.ShowDialog() | Out-Null