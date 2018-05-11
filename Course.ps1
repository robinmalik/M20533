# Requires -Modules AzureRM
<#
	.SYNOPSIS
		This script creates some of the resources created on the MA20533 course from QA.com.
	.DESCRIPTION
		This script creates some of the resources created on the MA20533 course from QA.com.
	.PARAMETER RGVNETName
		Resource Group name for networking related objects.
	.PARAMETER RGVMName
		Resource Group name for VMs.
	.PARAMETER Location
		Azure location (region) into which to deploy.
	.PARAMETER VNET1Name
		Name for Virtual Network 1 (VNET1)
	.PARAMETER VNET1AddressSpace
		Address space for VNET1.
	.PARAMETER VNET1Subnet1AddressRange
	.PARAMETER VNET1Subnet2AddressRange
	.PARAMETER VNET2Name
	.PARAMETER VNET2AddressSpace
	.PARAMETER VNET2Subnet1AddressRange
	.PARAMETER VirtualNetworkGatewayName
	.PARAMETER RouteTableName
	.PARAMETER PublicIPName
	.PARAMETER LBName
	.PARAMETER LBFrontEndPoolName
	.PARAMETER LBBackEndPoolName
	.PARAMETER LBProbeName
	.PARAMETER LBRuleName
	.OUTPUTS
		None
#>
    
[CmdletBinding()]
param
(
	[Parameter(Mandatory=$False)][String]$RGVNETName = 'VNETRG',
	[Parameter(Mandatory=$False)][String]$RGVMName = 'VMRG',
	[Parameter(Mandatory=$False)][String]$Location = 'Southeast Asia',
	[Parameter(Mandatory=$False)][String]$VNET1Name = 'SEA-VNET1',
	[Parameter(Mandatory=$False)][String]$VNET1AddressSpace = '192.168.0.0/16',
	[Parameter(Mandatory=$False)][String]$VNET1Subnet1AddressRange = '192.168.1.0/24',
	[Parameter(Mandatory=$False)][String]$VNET1Subnet2AddressRange = '192.168.2.0/24',
	[Parameter(Mandatory=$False)][String]$VNET2Name = 'SEA-VNET2',
	[Parameter(Mandatory=$False)][String]$VNET2AddressSpace = '172.16.0.0/16',
	[Parameter(Mandatory=$False)][String]$VNET2Subnet1AddressRange = '172.16.1.0/24',
	[Parameter(Mandatory=$False)][String]$VirtualNetworkGatewayName = 'SEA-Gateway',
	[Parameter(Mandatory=$False)][String]$VirtualNetworkGatewayPIPName = 'SEA-Gateway-IP',
	[Parameter(Mandatory=$False)][String]$RouteTableName = 'RouteTable1',
	[Parameter(Mandatory=$False)][String]$PublicIPName = 'NLB-IP',
	[Parameter(Mandatory=$False)][String]$LBName = 'NLB1',
	[Parameter(Mandatory=$False)][String]$LBFrontEndPoolName = 'FrontEndPool',
	[Parameter(Mandatory=$False)][String]$LBBackEndPoolName = 'BackEndPool',
	[Parameter(Mandatory=$False)][String]$LBProbeName = 'HealthProbe',
	[Parameter(Mandatory=$False)][String]$LBRuleName = 'LoadBalancerRule',
	[Parameter(Mandatory=$True)][SecureString]$AdminPassword
)

# As this script is for learning purposes, let's turn verbose on by default so we can
# see the output of the AzureRM cmdlets.
$VerbosePreference = 'Continue'

##################################################################################
# Prompt to login, if not already authenticated:
Write-Verbose -Message "Logging in..."
try { 
	Login-AzureRmAccount
}
catch {
	throw $_
}


##################################################################################
# IF REQUIRED, create a resource group:
if((Get-AzureRmResourceGroup -Name $RGVNETName -ErrorAction SilentlyContinue) -eq $null)
{
	Write-Verbose -Message "Creating object: $RGVNETName of type ResourceGroup"
	try {
		New-AzureRmResourceGroup -Name $RGVNETName -Location $Location -ErrorAction Stop
	}
	catch {
		throw $_
	}
} else {
	Write-Verbose -Message "ResourceGroup $RGVNETName already exists."
}


##################################################################################
# IF REQUIRED, define and create virtual network with two subnets:
if((Get-AzureRmVirtualNetwork -Name $VNET1Name -ResourceGroupName $RGVNETName -ErrorAction SilentlyContinue) -eq $null)
{
	Write-Verbose -Message "Creating object: $VNET1Name of type VirtualNetwork with two subnets."
	$SN1 = New-AzureRmVirtualNetworkSubnetConfig -Name 'SUBNET1' -AddressPrefix $VNET1Subnet1AddressRange
	$SN2 = New-AzureRmVirtualNetworkSubnetConfig -Name 'SUBNET2' -AddressPrefix $VNET1Subnet2AddressRange
    try {
        New-AzureRmVirtualNetwork -Name $VNET1Name -ResourceGroupName $RGVNETName -AddressPrefix $VNET1AddressSpace -Subnet $SN1,$SN2 -Location $Location -ErrorAction Stop
    }
    catch {
        throw $_       
	}
	
	# Get the virtual network object for use in other code:
	try {
		$vnet1 = Get-AzureRmVirtualNetwork -Name $VNET1Name -ResourceGroupName $RGVNETName -ErrorAction Stop
	}
	catch {
		throw $_
	}
} else {
    Write-Verbose -Message "VirtualNetwork $VNET1Name already exists."
}


##################################################################################
# IF REQUIRED, add a gateway subnet to the virtual network:
if($vnet1.Subnets.Name -notcontains 'GatewaySubnet')
{
    Write-Verbose -Message "Adding GatewaySubnet to $VNET1Name"
    Add-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet1 -AddressPrefix '192.168.3.0/29'
    try {
        Set-AzureRmVirtualNetwork -VirtualNetwork $vnet1 -ErrorAction Stop
    }
    catch {
        throw $_
	}
	
	# Re-get the virtual network object so it contains the Gateway subnet configuration in the subnets property - we use this later:
	try {
		$vnet1 = Get-AzureRmVirtualNetwork -Name $VNET1Name -ResourceGroupName $RGVNETName -ErrorAction Stop
	}
	catch {
		throw $_
	}
}
else {
    Write-Verbose -Message 'GatewaySubnet already exists.'
}


##################################################################################
# IF REQUIRED, define and create another virtual network with one subnet:
if((Get-AzureRmVirtualNetwork -Name $VNET2Name -ResourceGroupName $RGVNETName -ErrorAction SilentlyContinue) -eq $null)
{
	Write-Verbose -Message "Creating object: $VNET2Name of type VirtualNetwork with one subnet."
	$SN1 = New-AzureRmVirtualNetworkSubnetConfig -Name 'SUBNET1' -AddressPrefix $VNET2Subnet1AddressRange
    New-AzureRmVirtualNetwork -Name $VNET2Name -ResourceGroupName $RGVNETName -AddressPrefix $VNET2AddressSpace -Subnet $SN1 -Location $Location
    # Grab created virtual network object for later:
    $vnet2 = Get-AzureRmVirtualNetwork -Name $VNET2Name -ResourceGroupName $RGVNETName
}


##################################################################################
# Create a Virtual Network Gateway (VNG) and connect to VNET1. This 
# consists of a 4 steps:

###########################################
# 1. Get the existing gateway subnet configuration. This links to the VNG later:
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet1

###########################################
# 2. Create a public IP address:
Write-Verbose -Message "Creating object: $VirtualNetworkGatewayName of type PublicIP. This can take a while."
try {
	$Pip = New-AzureRMPublicIpAddress -Name $VirtualNetworkGatewayPIPName -ResourceGroupName $RGVNETName -Location $Location -AllocationMethod Dynamic -ErrorAction Stop	
}
catch {
	throw $_
}

###########################################
#3. Define the VNG configuration using the subnet ID and Public IP ID:
$ngwipconfig = New-AzureRMVirtualNetworkGatewayIpConfig -Name ngwipconfig -SubnetId $subnet.Id -PublicIpAddressId $Pip.Id

###########################################
# 4. Create the VNG:
Write-Verbose -Message "Creating object: $VirtualNetworkGatewayName of type VirtualNetworkGateway. This can take a while."
try {
	New-AzureRmVirtualNetworkGateway -Name $VirtualNetworkGatewayName -ResourceGroupName $RGVNETName -Location $Location -IpConfigurations $ngwIpConfig -GatewayType 'Vpn' -VpnType 'RouteBased' -GatewaySku 'Basic' -ErrorAction Stop	
}
catch {
	throw $_	
}



##################################################################################
# IF REQUIRED, deploy VM1, VM2, VM3 using JSON templates:
# IF REQUIRED, create a resource group:
if((Get-AzureRmResourceGroup -Name $RGVMName -ErrorAction SilentlyContinue) -eq $null)
{
    Write-Verbose -Message "Creating object: $RGVMName of type ResourceGroup"
    New-AzureRmResourceGroup -Name $RGVMName -Location $Location
} else {
    Write-Verbose -Message "ResourceGroup $RGVMName already exists."
}

# Changing these will not currently have any effect, as they're defined in the JSON files.
$VM1Name = 'VM1'
$VM2NAme = 'VM2'
$VM3Name = 'VM3'

if((Get-AzureRmVM -Name $VM1Name -ResourceGroupName $RGVMName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) -eq $null)
{
	Write-Verbose -Message "Creating object: $VM1Name of type VirtualMachine"
	try {
        New-AzureRmResourceGroupDeployment -ResourceGroupName $RGVMName -TemplateFile '.\VM1\template.json' -TemplateParameterFile '.\VM1\parameters.json' -adminPassword $AdminPassword -ErrorAction Stop
    }
    catch {
        $_
    }
} else {
	$Error.Remove($Error[0])
    Write-Verbose -Message "$VM1Name already exists."
}

if((Get-AzureRmVM -Name $VM2Name -ResourceGroupName $RGVMName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) -eq $null)
{
	Write-Verbose -Message "Creating object: $VM2Name of type VirtualMachine"
	try {
        New-AzureRmResourceGroupDeployment -ResourceGroupName $RGVMName -TemplateFile '.\VM2\template.json' -TemplateParameterFile '.\VM2\parameters.json' -adminPassword $AdminPassword -ErrorAction Stop
    }
    catch {
		$_
    }
} else {
	$Error.Remove($Error[0])
    Write-Verbose -Message "$VM2Name already exists."
}

if((Get-AzureRmVM -Name $VM3Name -ResourceGroupName $RGVMName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) -eq $null)
{
	Write-Verbose -Message "Creating object: $VM3Name of type VirtualMachine"
	try {
        New-AzureRmResourceGroupDeployment -ResourceGroupName $RGVMName -TemplateFile '.\VM3\template.json' -TemplateParameterFile '.\VM3\parameters.json' -adminPassword $AdminPassword -ErrorAction Stop
    }
    catch {
		$_
    }
} else {
	$Error.Remove($Error[0])
    Write-Verbose -Message "$VM3Name already exists."
}

##################################################################################
## Enable IP Forwarding on the Virtual Network Interface for VM1
try {
    $nic = Get-AzureRmNetworkInterface -ResourceGroupName $RGVMName | Where-Object { ($_.VirtualMachine).Id -like "*$VM1Name" }
    $nic.EnableIPForwarding = 1
    $nic | Set-AzureRmNetworkInterface -ErrorAction Stop
}
catch {
    Write-Verbose -Message "Could not set IP forwarding."
}


##################################################################################
# Manual steps to enable inbound ICMP on all VMs. Cannot do this with PowerShell
# as WinRM is not enabled.


##################################################################################
# VNET peering
try {
	# Peer VNet1 to VNet2.
	Write-Verbose -Message "Peering VNET1 to VNET2" 
	Add-AzureRmVirtualNetworkPeering -VirtualNetwork $vnet1 -RemoteVirtualNetworkId $vnet2.Id -Name 'Vnet1ToVnet2' -ErrorAction Stop
	# Peer VNet2 to VNet1.
	Write-Verbose -Message "Peering VNET2 to VNET1" 
	Add-AzureRmVirtualNetworkPeering -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet1.Id -Name 'Vnet2ToVnet1' -ErrorAction Stop
}
catch {
	$_
}



##################################################################################
# Create a route table and define a route:
try {
	New-AzureRmRouteTable -Name $RouteTableName -ResourceGroupName $RGVNETName -location $Location -ErrorAction Stop
	# Add a route to get to VNET1, Subnet 2.
	Get-AzureRmRouteTable -ResourceGroupName $RGVNETName -Name $RouteTableName | Add-AzureRmRouteConfig -Name "To-VNET1-Subnet2" -AddressPrefix '192.168.2.0/24' -NextHopType 'VirtualAppliance' -NextHopIpAddress '192.168.1.4' | Set-AzureRmRouteTable -ErrorAction Stop
	# Associate SUBNET1 from SEA-VNET2 with the RouteTable.
	$RouteTable = Get-AzureRmRouteTable -Name $RouteTableName -ResourceGroupName $RGVNETName
	Set-AzureRmVirtualNetworkSubnetConfig -Name 'SUBNET1' -VirtualNetwork $vnet2 -AddressPrefix $VNET2Subnet1AddressRange -RouteTableId $RouteTable.Id | Set-AzureRmVirtualNetwork -ErrorAction Stop
}
catch {
	$_
}


##################################################################################
# Open up Port 80 for the VM Network Security group:
try {
	Get-AzureRmNetworkSecurityGroup -Name 'VM-NSG' -ResourceGroupName $RGVMName | `
	Add-AzureRmNetworkSecurityRuleConfig -Name 'Port_80' -Description "Allow HTTP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1010 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 | Set-AzureRmNetworkSecurityGroup -ErrorAction Stop
}
catch {
	$_	
}



##################################################################################
# LOAD BALANCER STUFF:
try {
	# Create a Public IP address:
	Write-Verbose -Message "Creating object $PublicIPName of object type: PublicIP"
	try {
		$publicIP = New-AzureRmPublicIpAddress -ResourceGroupName $RGVNETName -Location $Location -AllocationMethod "Dynamic" -Name $PublicIPName -ErrorAction Stop
	}
	catch {
		throw $_
	}
	
	# Define a 'FrontEnd IP configuration' using the Public IP object: 
	$frontendIP = New-AzureRmLoadBalancerFrontendIpConfig -Name $LBFrontEndPoolName -PublicIpAddress $publicIP
	
	# Define a 'Backend Pool' configuration. This cmdlet only seems to accept a name (I had hoped you could specify which VMs/AVS you wanted to add):
	$backendPool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $LBBackEndPoolName
	
	# Define a probe check:
	$probe = New-AzureRmLoadBalancerProbeConfig -Name $LBProbeName -RequestPath '/' -Protocol http -Port 80 -IntervalInSeconds 16 -ProbeCount 2

	# Define a load balancing rule:
	$lbrule = New-AzureRmLoadBalancerRuleConfig -Name $LBRuleName -FrontendIpConfiguration $frontendIP -BackendAddressPool $backendPool -Protocol Tcp -FrontendPort 80 -BackendPort 80 -Probe $probe
	
	# CREATE the load balancer with the defined configuration above:
	$lb = New-AzureRmLoadBalancer `
	-ResourceGroupName $RGVNETName -Name $LBName -Location $Location -FrontendIpConfiguration $frontendIP `
	-BackendAddressPool $backendPool -Probe $probe -LoadBalancingRule $lbrule -ErrorAction Stop

	# Now set the LoadBalancerBackendAddressPools property on the network interface objects for VM1 and VM2 to contain the backend pool data.
	$NetworkInterfaces = Get-AzureRmNetworkInterface -ResourceGroupName VMRG -ErrorAction Stop
	$nic1 = $NetworkInterfaces | Where-Object { $_.VirtualMachine.Id -like "*/VM1" }
	$nic2 = $NetworkInterfaces | Where-Object { $_.VirtualMachine.Id -like "*/VM2" }
	$subnet1 = Get-AzureRmVirtualNetworkSubnetConfig -Name 'SUBNET1' -VirtualNetwork $vnet1 -ErrorAction Stop
	$subnet2 = Get-AzureRmVirtualNetworkSubnetConfig -Name 'SUBNET2' -VirtualNetwork $vnet1 -ErrorAction Stop
	$nic1 | Set-AzureRmNetworkInterfaceIpConfig -LoadBalancerBackendAddressPool $backendPool -Name 'ipconfig1' -Subnet $subnet1
	$nic1 | Set-AzureRmNetworkInterface -ErrorAction Stop
	$nic2 | Set-AzureRmNetworkInterfaceIpConfig -LoadBalancerBackendAddressPool $backendPool -Name 'ipconfig1' -Subnet $subnet2
	$nic2 | Set-AzureRmNetworkInterface -ErrorAction Stop
}
catch {
	Write-Verbose -Message "Could not create Load Balancer with all required config."
	$_
}


