# Introduction

In its current state, eduVPN needs client interaction in order to establish a VPN connection.

It is also possible, for Windows and macOS, to make eduVPN a system VPN that is always on via provisioning.

In this document we describe the steps in order to make this possible.

:warning: Currently we only support the WireGuard protocol

# Windows Cloud based provisioning
If you make use of Microsoft Endpoint Manager (previous Microsoft Intune) then this provision method might fit better within your IT infrastructure.
![image](https://user-images.githubusercontent.com/47246332/163172248-0841dd7d-ff6e-495a-9a5c-ce53dbff9760.png)

# Windows On-premise based provisioning
## Prerequisites
* An AD Windows server with Active Directory Certificate Services installed. Make sure that automatic enrollment of computer certificates via GPO is enabled: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/jj129705(v=ws.11)
* Fully set up eduVPN server.
* Git installed https://git-scm.com/download/win
* Windows configuration designer installed https://www.microsoft.com/nl-nl/p/windows-configuration-designer/9nblggh4tx22?rtc=1#activetab=pivot:overviewtab
* Download a wireguard msi https://download.wireguard.com/windows-client/
 
Here we create a PPKG file with Windows Configuration Designer. With the PPKG we can join Active Directory, install Wireguard and run a script that sets up eduVPN as a system VPN. If you already have a computer that is joined to Active Directory and has installed WireGuard you can skip these steps and go to step 3A.

## Step 1
Clone the repository:\
`git clone https://github.com/FlorisHendriks98/eduVPN-provisioning.git`

## Step 2
First open Windows Configuration designer and either import the example settings from eduVPN-provisioning/windowsConfigurationDesigner/exampleProject.icdproj or start a new project and specify the following settings:

![image](https://user-images.githubusercontent.com/47246332/162922774-0fd9081e-56bc-4435-aff6-b07b8630c01d.png)
Make sure that the computer name has a unique name, AD does not allow duplicate names. In order to be almost certain that we have a unique name we add %RAND:5% to the computer name which generates 5 random numbers.

Next go to ProvisioningCommmands/PrimaryContext/Command

Here we create an installation package for WireGuard. 
Enter a name for this command, e.g. Wireguard.

Specify the command, which uses the WireGuard msi to install WireGuard:
![image](https://user-images.githubusercontent.com/47246332/162794927-89f50056-448e-45ed-abbc-826655664263.png)

Finally we create another command, which provisions eduVPN. Enter a name for this command e.g. eduvpnProvision
![image](https://user-images.githubusercontent.com/47246332/162796810-7e4da036-5c16-49a0-aa65-b085999e0661.png)
Where eduVPN-provisioning/windows/eduvpnProvision.ps1 can be found in the cloned repository.

Go back to ProvisioningCommmands/PrimaryContext/Command. Make sure that the WireGuard installer is above the eduvpnProvision command:
![image](https://user-images.githubusercontent.com/47246332/162797244-3e62ac48-1258-4e19-b446-c743b287fdb0.png)

Export the configuration and download the PPKG file using the export button above.

## Step 3
Use this PPKG file to provision multiple windows devices. You can either use it during the OOBE, or in the settings of Windows at Accounts > Access work or school > Add or remove a provisioning package. 

## Step 3A
If the computer already has joined Active directory and installed WireGuard, you can just run the eduvpnProvision.ps1 on the client computer and set it up that way. 
Open command line as administrator and run:\
`powershell.exe -ExecutionPolicy ByPass ./eduvpnProvision.ps1`

## Step 4
You can check if the VPN tunnel is running by using the command `wg show` in an administrator command prompt:
![image](https://user-images.githubusercontent.com/47246332/162983449-78ef667a-08ff-499b-ac8e-e6f941c1d10e.png)


# MacOS On-premise based provisioning
## Prerequisites
* An AD Windows server with Active Directory Certificate Services installed. Make sure that automatic enrollment of computer certificates via GPO is enabled: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/jj129705(v=ws.11)
* Fully deployed eduVPN server.
* macOS server with profilemanager enabled.
* Git installed.

## Step 1
Here we configure a profile for the macOS client. With this profile we enroll the macOS client in AD and retrieve a machine certificate via RPC.

First open the my devices web application and enroll the device to macOS server.

![Screenshot 2022-04-11 at 13 17 40](https://user-images.githubusercontent.com/47246332/162730069-cd00267a-0f97-4e0b-8e18-f3b848757996.png)

Next open the profile manager web application and edit the following settings for a device or group of devices (make sure that the Certificate Server and the Certificate Authority has the names of your own infrastructure):
* AD certificate

![Screenshot 2022-04-11 at 13 32 43](https://user-images.githubusercontent.com/47246332/162731516-ebbc1911-e137-4344-b7ee-bccf0b7f4f03.png)

* Directory (you can skip this step if the computer is already AD joined)

![Screenshot 2022-04-11 at 14 52 09](https://user-images.githubusercontent.com/47246332/162743771-611df4c5-a679-447e-bedc-4ec7880cc8c0.png)

Note that we use as client ID %SerialNumber%, this ensures us that we do not have a duplicate name in Active Directory (https://discussions.apple.com/thread/7987975). If you want to use a different client ID, such as the hostname of the client, then the syntax can be found here https://support.apple.com/en-gb/guide/deployment/dep23422775/web.

After saving the profile configuration check if it is automatically pushed to the macOS client. If not, download and install it manually (https://support.apple.com/en-gb/guide/profile-manager/pmdbd71ebc9/mac). 

## Step 2
Check the keychain access, you should now have a certificate with the name SERIALNUMBER.HOSTNAME. This is the machine certificate which is used to authenticate API calls in order to retrieve a VPN configuration.

Open up the terminal and clone the repository:\
`git clone https://github.com/FlorisHendriks98/eduVPN-provisioning.git`

Install the HomeBrew package manager:\
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

Install Wireguard-tools, grep and coreutils:\
`brew install wireguard-tools grep coreutils`

Traverse to the macOS directory:\
`cd eduVPN-provisioning/macOS`

Run the setup.sh:\
`sudo ./setup.sh`

Check if Wireguard is up and running:\
`sudo wg show`

If it returns a config we are all set!


# Troubleshooting
Here I document all my issues I encountered while exploring how to setup eduVPN provisioning and what I did to resolve them.
## Machine certificates are not pushed to the clients
Check the Active Directory Certificate Services
![image](https://user-images.githubusercontent.com/47246332/163173607-c8409f7d-faab-4929-926e-75c32a21ed0f.png)

## MacOS doesn't accept the MDM 
