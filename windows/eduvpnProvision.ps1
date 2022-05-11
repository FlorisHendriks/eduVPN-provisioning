# Handle command-line arguments
param (
    [string]$s,
    [string]$p
 )
if((-not($s)) -or (-not($p)))
{
	Throw "You did not (fully) specify the parameters -s and -p"
}

# We need to have an internet connection to be able to start a WireGuard connection.
"try{
	while(-not (Test-Connection $s -Quiet -Count 1))
	{
		Start-Sleep -s 5
	}

	`$service = Get-Service -Name 'WireGuardTunnel`$wg0' -ErrorAction SilentlyContinue
	if(`$service -ne `$null)
	{
		Start-Service -InputObject `$service
	}

	`$initial = `$true

	`$certStorePath  = `"Cert:\LocalMachine\My`"
	`$name = hostname
	`$MachineCertificate = Get-ChildItem -Path `$certStorePath | Where-Object {`$_.Subject -like `"*`$name*`"}

	`$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

    while((`$MachineCertificate -eq `$null) -and `$timer.Elapsed.TotalMinutes -lt 60){
        Start-Sleep -s 60
        `$MachineCertificate = Get-ChildItem -Path `$certStorePath | Where-Object {`$_.Subject -like `"*`$name*`"}
    }

    if(`$MachineCertificate -eq `$null){
        `"We couldn't find a machine certificate at Cert:\LocalMachine\My with the name: `$name`" | Out-File -FilePath `"C:\Program Files\WireGuard\Data\eduVPNlog.txt`"
        exit 1
    }

	if(Test-Path -Path `"C:\Program Files\WireGuard\Data\wg0Expiry.txt`" -PathType Leaf)
	{
		`$WireguardDate = Get-Content `"C:\Program Files\WireGuard\Data\wg0Expiry.txt`"
		`$MachineCertificateDate = Get-Date -Date `$Machinecertificate.NotAfter
		`$initial = `$false
	}

	if((`$WireguardDate -lt `$MachineCertificateDate) -or `$initial)
	{
		`$service = Get-Service -Name 'WireGuardTunnel`$wg0'
		
		if(`$service.Status -eq 'Running'){
			Stop-Service -InputObject `$service
		}
		
		`$postParams = @{profile_id=`"$p`"}

		`$response = Invoke-WebRequest -Uri https://$s/vpn-user-portal/api/v3/provision -Headers @{'Accept' = 'application/x-wireguard-profile'} -Body `$postParams -UseBasicParsing -Certificate `$Machinecertificate -Method Post
		
		if(`$response.StatusCode -eq 200)
		{
			[System.Text.Encoding]::UTF8.GetString(`$response.Content) | Out-File -FilePath 'C:\Program Files\WireGuard\Data\wg0.conf'

			`$response.Headers.Expires | Get-Date | Out-File -FilePath 'C:\Program Files\WireGuard\Data\wg0Expiry.txt'
			
			Start-Process -FilePath `"C:\Windows\System32\cmd.exe`" -verb runas -ArgumentList {/c `"`"C:\Program Files\WireGuard\wireguard.exe`" /installtunnelservice `"C:\Program Files\WireGuard\Data\wg0.conf`"`"}
		}
		else{
			Start-Service -InputObject `$service
		}
	}
}
catch{
    `$_ | Out-File -FilePath `"C:\Program Files\WireGuard\Data\eduVPNlog.txt`"
}
" | Out-File -FilePath "C:\Program Files\WireGuard\Data\wireguardRenewal.ps1"

#Create a scheduled task that checks whether the wireguard configuration expires faster than the machine certificate, if so it retrieves a new wireguard configuration
$triggerDaily= New-ScheduledTaskTrigger -At 11:00pm -Daily # Specify the trigger settings
$triggerStartup = New-ScheduledTaskTrigger -AtStartup

$triggers = @($triggerDaily,$triggerStartup)

# We also want our script to run when we are on batteries
$runOnBatteries = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries

$user= "NT AUTHORITY\SYSTEM" # Specify the account to run the script, in our case the System User
$action= New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-executionpolicy bypass -File `"C:\Program Files\WireGuard\Data\wireguardRenewal.ps1`"" # Specify what program to run and with its parameters
Register-ScheduledTask -TaskName "RenewalVpnConfig" -Settings $runOnBatteries -Trigger $triggers -User $user -Action $action -RunLevel Highest -Force # Specify the name of the task

# Run the task
Start-ScheduledTask -TaskName "RenewalVpnConfig"
