$vol = Get-Volume

$DL = $vol.DriveLetter|?{$_ -gt "F"}

$englishLetterList = @()
for($i = 90; $i -ge 71; $i--){$englishLetterList += [string][char]($i)}

$k = 0;
Foreach($char in $DL)
{ 
	set-partition -driveletter $char -newdriveletter $englishLetterList[$k]
	$k++
	
}

