#!/bin/bash
set -e

declare -A ports=(
    ["SSH"]="22"
    ["RDP"]="3389"
)

usage() { echo "Usage: $0 [-g VMResourceGroup] [-n VMName] [-p <NSGRulePriority>] [-s <SSH/RDP>]" 1>&2; exit 1; }

while getopts ":g:n:p:s:" o; do
    case "${o}" in
        g)
            resourcegroup=${OPTARG}
            ;;
        n)
            vmname=${OPTARG}
            ;;
        p)
            priority=${OPTARG}
            if [ $priority -lt 100 ] || [ $priority -gt 4096 ]; then
                usage
            fi
            ;;
        s)
            service=${OPTARG}
            
            if [ $service != "SSH" ] && [ $service != "RDP" ]; then
                echo $service
                usage
            fi
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${resourcegroup}" ]; then
    read -p "ResourceGroup: " resourcegroup
fi
if [ -z "${vmname}" ]; then
    read -p "VmName: " vmname
fi
if [ -z "${resourcegroup}" ] || [ -z "${vmname}" ]; then
    usage
fi

if [ -z "${priority}" ]; then
    priority=100
fi

if [ -z "${service}" ]; then
    service="SSH"
fi

# get source address prefix
pip=$(dig -4 +short myip.opendns.com @resolver1.opendns.com)
sourcecidr="$pip/32"
echo "Source IP Address = $pip"

# get nic id
nicid=$(az vm show --resource-group "$resourcegroup" --name "$vmname" --query networkProfile.networkInterfaces[].id -o tsv)

# get nic nsg group and name
nicnsgid=$(az network nic show --ids "$nicid" --query networkSecurityGroup.id -o tsv)
if [ -z "$nicnsgid" ]; then
    nicnsgid=$(az network nsg create --resource-group $resourcegroup --name nicnsg --query NewNSG.id -o tsv)
    az network nic update --ids $nicid --network-security-group $nicnsgid -o table
fi
nicnsggroup=$(echo $nicnsgid | cut -d '/' -f 5)
nicnsgname=$(echo $nicnsgid | cut -d '/' -f 9)

# get subnet nsg group and name
subnetid=$(az network nic show --ids "$nicid" --query ipConfigurations[].subnet.id -o tsv)
subnetnsgid=$(az network vnet subnet show --ids "$subnetid" --query networkSecurityGroup.id -o tsv)
if [ -z "$subnetnsgid" ]; then
    subnetnsgid=$(az network nsg create --resource-group $resourcegroup --name subnetnsg --query NewNSG.id -o tsv)
    az network vnet subnet update --ids $subnetid --network-security-group $subnetnsgid -o table
fi
subnetnsggroup=$(echo $subnetnsgid | cut -d '/' -f 5)
subnetnsgname=$(echo $subnetnsgid | cut -d '/' -f 9)

az network nsg rule create --resource-group $nicnsggroup --nsg-name $nicnsgname --name "$service" --priority $priority --direction Inbound --protocol Tcp --source-address-prefixes $sourcecidr --destination-port-ranges ${ports[$service]} -o table
az network nsg rule create --resource-group $subnetnsggroup --nsg-name $subnetnsgname --name "$service" --priority $priority --direction Inbound --protocol Tcp --source-address-prefixes $sourcecidr --destination-port-ranges ${ports[$service]} -o table