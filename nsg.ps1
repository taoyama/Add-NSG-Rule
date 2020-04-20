param (
        [parameter(mandatory=$true)][string]$ResourceGroupName,
        [parameter(mandatory=$true)][string]$VMName
)

$Nic = Get-AzNetworkInterface -ResourceId (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName).NetworkProfile.NetworkInterfaces.Id
$NicNSGGroup = $Nic.NetworkSecurityGroup.Id.Split("/")[4]
$NicNSGName = $Nic.NetworkSecurityGroup.Id.Split("/")[8]

$Subnet = (Get-AzVirtualNetworkSubnetConfig -ResourceId $Nic.IpConfigurations.Subnet.Id)
$SubnetNSGGroup = $Subnet.NetworkSecurityGroup.Id.Split("/")[4]
$SubnetNSGName = $Subnet.NetworkSecurityGroup.Id.Split("/")[8]

$NicNSG = Get-AzNetworkSecurityGroup -ResourceGroupName $NicNSGGroup -Name $NicNSGName
$SubnetNSG = Get-AzNetworkSecurityGroup -ResourceGroupName $SubnetNSGGroup -Name $SubnetNSGName

function UpdateNSG ($NSG) {
    Remove-AzNetworkSecurityRuleConfig -Name "RDP" -NetworkSecurityGroup $NSG | Out-Null
    Add-AzNetworkSecurityRuleConfig -Name "RDP" -Access Allow `
    -Protocol TCP -Direction Inbound -Priority 100 -SourceAddressPrefix "$sourcecidr" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange "3389" -NetworkSecurityGroup $NSG | Out-Null
    $NSG | Set-AzNetworkSecurityGroup | Format-List Name, ProvisioningState
}

$pip=(Invoke-WebRequest ifconfig.me/ip).Content.Trim()
$sourcecidr="$pip/32"
Write-Output "Source IP Address = $pip"

UpdateNSG($NicNSG)
UpdateNSG($SubnetNSG)