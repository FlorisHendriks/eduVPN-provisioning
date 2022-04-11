# Introduction

In its current state, eduVPN needs client interaction in order to establish a VPN connection.

It is also possible, for Windows and MacOS, to make eduVPN a system VPN that is always on via provisioning.

In this document we describe the steps in order to make this possible.

# Windows
## Prerequisites
* An AD Windows server with Active Directory Certificate Services installed. Make sure that automatic enrollment of computer certificates via GPO is enabled: https://www.youtube.com/watch?v=l03jXuR6dJw
* Fully set up eduVPN server.



# MacOS
## Prerequisites
* An AD Windows server with Active Directory Certificate Services installed. Make sure that automatic enrollment of computer certificates via GPO is enabled: https://www.youtube.com/watch?v=l03jXuR6dJw
* Fully deployed eduVPN server.
* macOS server with profilemanager enabled.

## Step 1
Here we configure a profile for the macOS client. With this profile we enroll the macOS client in AD and retrieve a machine certificate via RPC.

First open up the profilemanager web application
![image](https://user-images.githubusercontent.com/47246332/162724047-c47636a3-8ed1-4800-a745-8b86d0746b0c.png)


