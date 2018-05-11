# M20533

A mix of pure PowerShell and ARM templates to replicate part of what I covered on the Microsoft Implementing Azure Infrastructure Solutions course with QA.com. As the course used standard Windows Server templates, without WinRM, it's impossible to remote into them and install components like IIS and RRAS (as we did in the course). There are multiple ways to solve this problem, but they are not addressed here.

The main PowerShell script contains default parameter values using the naming convention used on the course, meaning it can be run without any prompts. Alternatively you may specify your own values when calling the script, if you wish.

The script is large, primarily due to commenting, error handling each cmdlet call, and also using code to check if any resources already exist; if resources already exist, the code block will be skipped. The advantage of this is that if the script fails, you can merely call it again rather than having to delete all previously created Azure objects in order to start again.

## The following is coded for:

1. Initial resource group
2. Virtual Networks and subnets.
3. Addition of Virtual Gateway to first subnet.
4. Creation of resource group for VMs.
5. Deployment of 3 x VMs to the appropriate subnets, using ARM templates (JSON files, stored in folders: VM1, VM2, VM3).
6. Enabling IP forwarding on the network interface of VM1.
7. Peering VNET1 and VNET2.
8. Adding a route table and configuration to route traffic from VNET2 to VM1 in VNET1.
9. Opening up port 80 on the VM Network Security Group.
10. Creating a load balancer (upto to the point at which you must add an availablity set to it - sure how to do this at present)

## Requirements
 - PowerShell 5+.
 - AzureRM module (`Install-Module -Name AzureRM` if need be, from PowerShell).

## Usage
1. If you installed the AzureRM module, close and reopen PowerShell.
2. Run Course.ps1