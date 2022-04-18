# Introduction

eduVPN is used to provide (large groups of) users a secure way to access the internet and their organisational resources. The goal of eduVPN is to replace typical closed-source VPNs with an open-source validated alternative that works seamlessly with an organisational identity environment.

Currently, eduVPN authorization works as follows: first, a user installs the eduVPN app on its computer. The user then searches for his or her organisation which opens a web browser to the organisation's Identity Provider. The Identity Provider verifies the credentials of the user and if correct, sends back an OAuth token. With that OAuth token, the client application requests an OpenVPN or WireGuard configuration file. When the client receives a configuration file back, it authenticates to either the OpenVPN or WireGuard server and establishes the connection.

![image](https://user-images.githubusercontent.com/47246332/163761407-4f18df06-8300-4fe9-b10d-d640234b96c4.png)

One limitation that this authorization protocol has is that the VPN connection is established only after a user logs in to Windows. Often, organisations only allow clients through a VPN connection to communicate with their Active Directory in order to mitigate potential cyber security risks. However, when a user wants to log in with its user credentials for the first time, it needs to be able to communicate with Active Directory to verify those credentials. But the VPN only starts after a user logs in, so in this case the user can't log into its computer. We therefore need to find a way to establish a VPN connection before a user logs in to Windows.

Another limitation is that some organisations have set the expiration date of the configuration files to less than a day, for security reasons. As a result, eduVPN users dislike the fact that they need to log in each day. Moreover, even if the configurations have a longer expiration date, there is still user interaction needed to establish the vpn connection. This is an extra threshold before a user can use organisational resources. 

In this document we are going to solve these limitations by making eduVPN a system VPN that is always on via provisioning.
We realize this by using Active Directory Certificate Services. Every joined device gets a machine certificate. We use that certificate to authenticate an API call where we retrieve a WireGuard config. Next we install the WireGuard tunnel with that config. To visualise this:

![image](https://user-images.githubusercontent.com/47246332/163763513-4c12f662-e567-429e-a67e-d99a9b9bfb84.png)

Down below we describe the steps in order to make this possible.

**Note:** Currently we only support the WireGuard protocol



# Windows
## Prerequisites
* An AD Windows server with Active Directory Certificate Services installed. Make sure that automatic enrollment of computer certificates via GPO is enabled: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/jj129705(v=ws.11)
* Fully set up eduVPN server.
* Git installed https://git-scm.com/download/win
* Windows configuration designer installed https://www.microsoft.com/nl-nl/p/windows-configuration-designer/9nblggh4tx22?rtc=1#activetab=pivot:overviewtab
* Download a wireguard msi https://download.wireguard.com/windows-client/
 
Here we create a PPKG file with Windows Configuration Designer. With the PPKG we can join Active Directory, install Wireguard and run a script that sets up eduVPN as a system VPN.

## Step 1
Clone the repository:\
`git clone https://github.com/FlorisHendriks98/eduVPN-provisioning.git`

## Step 2
First open Windows Configuration designer and either import the example settings from eduVPN-provisioning/windowsConfigurationDesigner/exampleProject.icdproj or start a new project and specify the settings to join Active Directory:

![image](https://user-images.githubusercontent.com/47246332/162922774-0fd9081e-56bc-4435-aff6-b07b8630c01d.png)
If the computer already is joined to (Azure) AD you **must** not specify these settings, the provision package will not work if you do.

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
Use this PPKG file to provision multiple windows devices. You can either use it during the OOBE, in the settings of Windows at Accounts > Access work or school > Add or remove a provisioning package or in an elevated command prompt:\
`powershell.exe “Add-ProvisioningPackage -Path “XXXXX.ppkg” -ForceInstall -QuietInstall”`

### Optional: Bulk deploy the PPKG with Microsoft Endpoint manager (intune)
You can also deploy the PPKG by using the powershell script functionality of the Microsoft Endpoint manager.
Learn [here](https://www.anoopcnair.com/deploy-ppkg-files-with-intune/) how to do this.


## Step 3A
If the computer already has joined Active directory and installed WireGuard, you can just run the eduvpnProvision.ps1 on the client computer and set it up that way. 
Open command line as administrator and run:\
`powershell.exe -ExecutionPolicy ByPass ./eduvpnProvision.ps1`

## Step 4
You can check if the VPN tunnel is running by using the command `wg show` in an administrator command prompt:
![image](https://user-images.githubusercontent.com/47246332/162983449-78ef667a-08ff-499b-ac8e-e6f941c1d10e.png)


# MacOS
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

## My provisioning package gives the error 0x800700b7.
The device is probably already enrolled in (Azure) Active Directory. Create the PPKG without configuring the AD join.

## MacOS doesn't accept the MDM 

# Future work
* Add support for OpenVPN
* Make a UI for selecting different profiles
