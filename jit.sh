#!/bin/bash
set -e

declare -A ports=(
    ["SSH"]="22"
    ["RDP"]="3389"
)

usage() { echo "Usage: $0 [-g VMResourceGroup] [-n VMName]" 1>&2; exit 1; }

while getopts "g:n:" o; do
    case "${o}" in
        g)
            resourcegroup=${OPTARG}
            ;;
        n)
            vmname=${OPTARG}
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

IFS=$'\r\n' eval 'vminfo=($(az vm show -g ${resourcegroup} -n ${vmname} -o tsv --query "[id, location, storageProfile.osDisk.osType]"))'
vmid="${vminfo[0]}"
location="${vminfo[1]}"
osType=${vminfo[2]}
subid=$(echo $vmid | cut -d \/ -f 3)

echo "osType: $osType"
if [ $osType == "Linux" ]; then
	service="SSH"
elif [ $osType == "Windows" ]; then
	service="RDP"
else
	echo "unknown osType"
	exit 1;
fi

# get source address prefix
pip=$(dig -4 +short myip.opendns.com @resolver1.opendns.com)
sourcecidr="$pip/32"
echo "Source IP Address: $pip"

# https://docs.microsoft.com/en-us/rest/api/securitycenter/jit-network-access-policies/delete
# https://docs.microsoft.com/en-us/rest/api/securitycenter/jit-network-access-policies/create-or-update
enable_jit() {
	URI="https://management.azure.com/subscriptions/${subid}/resourceGroups/${resourcegroup}/providers/Microsoft.Security/locations/${location}/jitNetworkAccessPolicies/default?api-version=2020-01-01"
	BODY=$(cat << EOS
{
    "kind": "Basic",
    "properties": {
        "virtualMachines": [
            {
                "id": "${vmid}",
                "ports": [
                    {
                        "number": 22,
                        "protocol": "TCP",
                        "allowedSourceAddressPrefix": "${pip}",
                        "maxRequestAccessDuration": "PT3H"
                    },
                    {
                        "number": 3389,
                        "protocol": "TCP",
                        "allowedSourceAddressPrefix": "${pip}",
                        "maxRequestAccessDuration": "PT3H"
                    }
                ]
            }
        ]
    }
}
EOS
)
	az rest --verbose --method delete --uri "${URI}"
	az rest --verbose --method put --uri "${URI}" --body "${BODY}"
}

# https://docs.microsoft.com/en-us/rest/api/securitycenter/jit-network-access-policies/initiate
initiate_jit() {
	URI="https://management.azure.com/subscriptions/${subid}/resourceGroups/${resourcegroup}/providers/Microsoft.Security/locations/${location}/jitNetworkAccessPolicies/default/initiate?api-version=2020-01-01"
	BODY=$(cat <<EOS
{
    "virtualMachines": [
        {
            "id": "${vmid}",
            "ports": [
                {
                    "number": ${ports[$service]},
                    "duration": "PT3H",
                    "allowedSourceAddressPrefix": "${pip}"
                }
            ]
        }
    ]
}
EOS
)
	az rest --verbose --method post --uri "${URI}" --body "${BODY}"
}

enable_jit
initiate_jit

