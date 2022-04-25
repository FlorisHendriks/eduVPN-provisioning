# We need to have an internet connection to be able to start a WireGuard connection.
"while(-not ((Test-NetConnection `"vpn.strategyit.nl`").PingSucceeded))
{
	Start-Sleep -s 5
}

`$service = Get-Service -Name 'WireGuardTunnel`$wg0' -ErrorAction SilentlyContinue
if(`$service -ne `$null)
{
    Start-Service -InputObject `$service
}

`$sn = gwmi win32_bios | select -Expand serialnumber

`$initial = `$true

`$certStorePath  = `"Cert:\LocalMachine\My`"
`$name = hostname
`$MachineCertificate = Get-ChildItem -Path `$certStorePath | Where-Object {`$_.Subject -like `"*`$sn*`"}

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
	
    `$postParams = @{profile_id='default'}

    `$response = Invoke-WebRequest -Uri https://vpn.strategyit.nl/vpn-user-portal/api/v3/provision -Headers @{'Accept' = 'application/x-wireguard-profile'} -Body `$postParams -UseBasicParsing -Certificate `$Machinecertificate -Method Post
    
    if(`$response.StatusCode -eq 200)
    {
        [System.Text.Encoding]::UTF8.GetString(`$response.Content) | Out-File -FilePath 'C:\Program Files\WireGuard\Data\wg0.conf'

		`$response.Headers.Expires | Get-Date | Out-File -FilePath 'C:\Program Files\WireGuard\Data\wg0Expiry.txt'
        
		Start-Process -FilePath `"C:\Windows\System32\cmd.exe`" -verb runas -ArgumentList {/c `"`"C:\Program Files\WireGuard\wireguard.exe`" /installtunnelservice `"C:\Program Files\WireGuard\Data\wg0.conf`"`"}
    }
    else{
        Start-Service -InputObject `$service
    }
}" | Out-File -FilePath "C:\Program Files\WireGuard\Data\wireguardRenewal.ps1"

#Create a scheduled task that checks whether the wireguard configuration expires faster than the machine certificate, if so it retrieves a new wireguard configuration
$triggerDaily= New-ScheduledTaskTrigger -At 11:00pm -Daily # Specify the trigger settings
$triggerStartup = New-ScheduledTaskTrigger -AtStartup

$triggers = @($triggerDaily,$triggerStartup)

$user= "NT AUTHORITY\SYSTEM" # Specify the account to run the script, in our case the System User
$action= New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-executionpolicy bypass -File `"C:\Program Files\WireGuard\Data\wireguardRenewal.ps1`"" # Specify what program to run and with its parameters
Register-ScheduledTask -TaskName "RenewalVpnConfig" -Trigger $triggers -User $user -Action $action -RunLevel Highest -Force # Specify the name of the task

# Run the task
Start-ScheduledTask -TaskName "RenewalVpnConfig"
