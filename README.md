# Introduction

eduVPN is used to provide (large groups of) users a secure way to access the internet and their organisational resources. The goal of eduVPN is to replace typical closed-source VPNs with an open-source audited alternative that works seamlessly with an enterprise identity solution.

Currently, eduVPN authorization works as follows: first, a user installs the eduVPN client on a supported device. When starting the client, the user searches for his or her organisation which opens a web page to the organisation's Identity Provider. The Identity Provider verifies the credentials of the user and notifies the OAuth server whether they are valid or not. The OAuth server then sends back an OAuth token to the user. With that OAuth token, the client application requests an OpenVPN or WireGuard configuration file. When the client receives a configuration file, it authenticates to either the OpenVPN or WireGuard server and establishes the connection (see the Figure below for the protocol overview).

![currentAuthorization](https://user-images.githubusercontent.com/47246332/164429497-dc4c90e3-944e-4eb1-8482-5f516ae14d52.png)

A limitation of this authorization protocol is that the VPN connection can only be established after a user logs in to the device. Many organisations offer managed devices, meaning that they are enrolled into (Azure) Active Directory. Often, organisations only allow clients through either a VPN connection to communicate with their (Azure) Active Directory in order to mitigiate potential security risks. However, this can cause problems. If a new user wants to log in to a managed device, the device needs to be able to communicate with Active Directory to verify those credentials. This is not possible because the VPN is not active yet.

Moreover, this authorization protocol can be seen as an extra threshold for the user to use the VPN. The user needs to start up the client, connect and log in (if the configuration is expired).

# Solution
In this document we are going to solve these drawbacks of the current authorization flow by making eduVPN a system VPN that is always on via provisioning. So instead of making the user interact with a eduVPN client to establish a VPN connection we are going to do that via a script that runs in the background.

We realize this by using Active Directory Certificate Services with automatic enrollment enabled so that every joined device retrieves a machine certificate. We use that certificate to authenticate an API call where we retrieve a WireGuard config. Next we install the WireGuard tunnel with that config. To visualise this:

![authorizationflow drawio(1)](https://user-images.githubusercontent.com/47246332/164447445-37338b6d-efc9-4247-9c77-238b3841da26.png)

**Design choices:**
* **Active Directory Certificate Services**: We chose to use the Microsoft PKI since that is broadly used by large organisations. Moreover, the Windows PKI has nice integration with the Windows Certificate Store. Of course you can use your own PKI but note that you need to tweak some code in the script.
* **MacOS/Windows**: Most organizations that give their employees a managed device have either Windows or MacOS. We are therefore focused on supporting Windows and MacOS. For future work someone might extend this support to Linux.
* **WireGuard/OpenVPN**: When trying to implement eduVPN provisioning we looked mainly at supporting WireGuard due to time constraints. If there is time left we will add support for OpenVPN.

Down below we describe the steps in order to make eduVPN provisioning possible.

**Note:** Currently we only support Macos/Windows and the WireGuard protocol.

# Windows
## Prerequisites
* An AD Windows server with Active Directory Certificate Services installed. [Make sure that automatic enrollment of computer certificates via GPO is enabled](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/jj129705(v=ws.11))
* [A deployed eduVPN server that has support for provisioning](https://github.com/FlorisHendriks98/provisionPackage)
* [Git installed](https://git-scm.com/download/win)
* [Windows configuration designer installed](https://www.microsoft.com/nl-nl/p/windows-configuration-designer/9nblggh4tx22?rtc=1#activetab=pivot:overviewtab)
* [Download a WireGuard msi](https://download.wireguard.com/windows-client/)
* A Windows client with Windows 10/11
 
Here we create a Provisioning Package ([PPKG](https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provisioning-packages)) file with Windows Configuration Designer. With the PPKG we can join Active Directory, install Wireguard and run a script that sets up eduVPN as a system VPN.

## Step 1
Clone the repository:\
`git clone https://github.com/FlorisHendriks98/eduVPN-provisioning.git`

## Step 2
Open Windows Configuration designer and either import the example settings from eduVPN-provisioning/windowsConfigurationDesigner/exampleProject.icdproj or start a new project and specify the settings to join Active Directory:

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


# macOS
Unfortunately automatic certificate enrollment with macOS does not work. We therefore have to find a way to retrieve a machine certificate from ADCS and push it to the macOS client. Previously we solved it with using macOS server by doing a DCE / RPC call, [but as of 21 April 2022 macOS server is deprecated.](https://support.apple.com/en-us/HT208312). Apple suggests to use a third party MDM as an alternative to macOS server. We choose to use Microsoft Endpoint Manager, as it is a well established MDM provider and integrates great with ADCS.
## Prerequisites
* [An AD Windows server with Active Directory Certificate Services installed.](https://docs.microsoft.com/en-us/windows-server/networking/core-network-guide/cncg/server-certs/install-the-certification-authority)
* [Configure MDM](https://docs.microsoft.com/en-us/windows/client-management/mdm/azure-ad-and-microsoft-intune-automatic-mdm-enrollment-in-the-new-portal)
* Configure a [PKCS](https://docs.microsoft.com/en-us/mem/intune/protect/certificates-pfx-configure) or [SCEP](https://docs.microsoft.com/en-us/mem/intune/protect/certificates-scep-configure) machine certificate profile with Microsft Endpoint Manager.
* Git installed.
* A MacOS client with Monterey installed.

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
Here I document all my issues we encountered while exploring how to setup eduVPN provisioning and what I did to resolve them.

## My provisioning package gives the error 0x800700b7.
The device is probably already enrolled in (Azure) Active Directory. Create the PPKG without configuring the AD join.

# Future work
* **Make a third-party MDM optional instead of mandatory**. Unfortunate for macOS we have to rely on a third party MDM in order to get the machine certificate. [More interestingly, there has been a github tool developed by twocanoes that does a DCE / RPC call to ADCS using a kerberos ticket.](https://twocanoes.com/ad-certificate-profile-got-macos-apple/) With that tool you are able to create a CSR on the macos device, send it to ADCS and receive a signed certificate back. Unfortunately, a limitation of this tool is that the signed certificate that is received from ADCS can only be stored in the user keychain. For future work it would be interesting to check if it is possible to store the certificate in the system keychain. This would mean that we do not have to rely on a third party MDM to get a machine certificate.
* **Add support for OpenVPN**. Due to time constraints we only managed to support WireGuard. There all still reasons to use OpenVPN, as it still supports TCP as opposed to WireGuard.
* **Make a UI for selecting different profiles and add support for multiple profiles**. Currently you can only manually specify the profile you want to connect with. However, it would be useful to have support to select multiple profiles so that the end user can choose.
* **Add support for Linux**. We only focused on supporting Windows and macOS to make eduVPN a system VPN as those OSs are the most used by organizations. Still, there are numerous people who use Linux so it would be nice to add support for that.
