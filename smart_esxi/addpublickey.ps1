# add public key to all hosts via ssh, adding it to keys-root and keys-autotester

$hosts ="srv1114.paragon-software.com"
	
	Foreach ($chost in $hosts) {
		Write-Host 	 "Connecting to $chost" -ForegroundColor Green
		
		$password = "lpc3TAWvbW" | ConvertTo-SecureString -asPlainText -Force
		$username = "root"
		$credential = New-Object System.Management.Automation.PSCredential($username,$password)
		New-SSHSession -ComputerName $chost -Credential $credential  -AcceptKey
		
		$localFile = "$ENV:Temp" + "\id_rsa.pub"
		$remoteFile = "/tmp/id_rsa.pub"
		
		Write-Host 	 "Copying key to $chost" -ForegroundColor Green

		Set-SCPFile -LocalFile $localFile  -RemotePath "/tmp/" -ComputerName $chost -Credential $credential

		Write-Host 	 "Invoke adding key to list $chost" -ForegroundColor Green
							
		Invoke-SshCommand -Index 0 -Command  "mkdir /etc/ssh/keys-autotester/"
		Invoke-SshCommand -Index 0 -Command  "touch /etc/ssh/keys-autotester/authorized_keys"
		
		Invoke-SshCommand -Index 0 -Command  "cat /tmp/id_rsa.pub >> /etc/ssh/keys-root/authorized_keys"
		Invoke-SshCommand -Index 0 -Command  "cat /tmp/id_rsa.pub >> /etc/ssh/keys-autotester/authorized_keys"
				
		Write-Host 	 "Delete key file from $chost" -ForegroundColor Green
		Invoke-SshCommand -Index 0 -Command  "rm  /tmp/id_rsa.pub "
		
		Write-Host 	 "Disconnecting from $chost" -ForegroundColor Green
		Remove-SSHSession -Index 0 -Verbose
		
		

	} 
	

