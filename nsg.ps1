#!/usr/bin/env pwsh

param (
        [parameter(mandatory=$true)][string]$ResourceGroupName,
        [parameter(mandatory=$true)][string]$VMName
)

function UpdateNSG ($NSG) {
    Remove-AzNetworkSecurityRuleConfig -Name "RDP" -NetworkSecurityGroup $NSG | Out-Null
    Remove-AzNetworkSecurityRuleConfig -Name "SSH" -NetworkSecurityGroup $NSG | Out-Null
    Add-AzNetworkSecurityRuleConfig -Name "RDP" -Access Allow `
    -Protocol TCP -Direction Inbound -Priority 100 -SourceAddressPrefix "$sourcecidr" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange "3389" -NetworkSecurityGroup $NSG | Out-Null
    $NSG | Set-AzNetworkSecurityGroup | Format-List Name, ProvisioningState
}

$Vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
$Location = $Vm.Location

$Nic = Get-AzNetworkInterface -ResourceId $Vm.NetworkProfile.NetworkInterfaces.Id
if ($NULL -eq $Nic.NetworkSecurityGroup) {
    $Nic.NetworkSecurityGroup = New-AzNetworkSecurityGroup -Name "nicnsg" -ResourceGroupName "$ResourceGroupName" -Location $Location
    $Nic | Set-AzNetworkInterface | Out-Null
}
$NicNSGGroup = $Nic.NetworkSecurityGroup.Id.Split("/")[4]
$NicNSGName = $Nic.NetworkSecurityGroup.Id.Split("/")[8]
$NicNSG = Get-AzNetworkSecurityGroup -ResourceGroupName $NicNSGGroup -Name $NicNSGName

$Subnet = (Get-AzVirtualNetworkSubnetConfig -ResourceId $Nic.IpConfigurations.Subnet.Id)
if ($NULL -eq $Subnet.NetworkSecurityGroup) {
    $VnetId = $Subnet.Id.Split("/subnets/")[0]
    $VnetGroup = $VnetId.Split("/")[4]
    $VnetName = $VnetId.Split("/")[8]
    $Vnet = Get-AzVirtualNetwork -ResourceGroup $VnetGroup -Name $VnetName
    $SubnetNSG = New-AzNetworkSecurityGroup -Name "subnetnsg" -ResourceGroupName "$ResourceGroupName" -Location $Location
    Set-AzVirtualNetworkSubnetConfig -Name $Subnet.Name -VirtualNetwork $Vnet -AddressPrefix $Subnet.AddressPrefix -NetworkSecurityGroup $SubnetNSG | Out-Null
    $Vnet | Set-AzVirtualNetwork | Out-Null
} else {
    $SubnetNSGGroup = $Subnet.NetworkSecurityGroup.Id.Split("/")[4]
    $SubnetNSGName = $Subnet.NetworkSecurityGroup.Id.Split("/")[8]
    $SubnetNSG = Get-AzNetworkSecurityGroup -ResourceGroupName $SubnetNSGGroup -Name $SubnetNSGName
}

$pip=(Invoke-WebRequest ifconfig.me/ip).Content.Trim()
$sourcecidr="$pip/32"
Write-Output "Source IP Address = $pip"

UpdateNSG($NicNSG)
UpdateNSG($SubnetNSG)

