function timeLog{
    Param
	(
		[string] $prmlog,
        [int] $netSize = 0
        
	)
	#
    [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
    
    $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
    $Chart.Width = 800 
    $Chart.Height = 600 
    $Chart.Left = 0 
    $Chart.Top = 0
    
    
    $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 
    $Chart.ChartAreas.Add($ChartArea)
    
    #
    $reader = [System.IO.File]::OpenText($prmlog)
    $currentDate = $null
    $counter = 0
    $deltaDict = New-Object System.Collections.Specialized.OrderedDictionary
    $deltaList = @()
    
    $max = 0
    $maxCounter = 0
    
    $total = 0
    $middle = 0
    $middleSqrt = 0
    

	try {
	    for(;;) {
            $item = $reader.ReadLine()
	        if ($item -eq $null) { break }
	        # process the line
	        $eventDate = Get-Date ($item -split ',')[0]
            if ($currentDate -eq $null)
            {
                $currentDate = $eventDate
            }
            
            $delta = ($eventDate - $currentDate).TotalSeconds
            
            if($delta -ge $netSize)
            {
                $total += $delta
                $deltaDict["$counter"] = $delta
                $deltaList += $delta
            }
                        
            if($delta -gt $max)
            {
                $max = $delta
                $maxCounter = $counter
            }
            
            
            $counter += 1
            $currentDate = $eventDate
            
		}
	}
	finally { $reader.Close() }
    
    $middle = $total/$counter
    foreach ($delta in $deltaList)
    {
        $middleSqrt += ($delta - $middle)*($delta - $middle)
    }
    $middleSqrt = [math]::sqrt($middleSqrt/$counter)
    #
    [void]$Chart.Series.Add("Data") 
    $Chart.Series["Data"].Points.DataBindXY($deltaDict.Keys, $deltaDict.Values)
    
    # display the chart on a form 
    $Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor 
                    [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left 
    $Form = New-Object Windows.Forms.Form 
    $Form.Text = "PRM Log Performance" 
    $Form.Width = 850 
    $Form.Height = 650 
    
    # add title and axes labels 
    
    $ChartArea.AxisX.Title = "recordNumber from Log (Max is in record $maxCounter).`n Total=$total. Max=$max. Middle=$middle. MiddleSqrt=$middleSqrt" 
    $ChartArea.AxisY.Title = "deltaValue in Seconds"

    $maxValuePoint = $Chart.Series["Data"].Points.FindMaxByValue() 
    $maxValuePoint.Color = [System.Drawing.Color]::Red
    
    $Chart.BackColor = [System.Drawing.Color]::Transparent
    
    $Form.controls.add($Chart) 
    $Form.Add_Shown({$Form.Activate()}) 
    $Form.ShowDialog()
    #
}

$filename = $args[0]
$netSize = $args[1]
if(-not $args[0])
{
    write-host "example of using: LogPerf.ps1 c:\prmlog.log"
    exit
}
if(-not (test-path $args[0]))
{
    write-host ("example of using: LogPerf.ps1 c:\prmlog.log")
    write-host ("cannot find path: $filename")
    exit
}

timeLog $filename $netSize