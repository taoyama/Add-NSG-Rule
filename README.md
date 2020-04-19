# Add-NSG-Rule

## Description
This script detect your IP to connect internet.
And then create rule to allow ssh from the IP.

## Usage
specify ResourceGroupName and VMName
```bash
curl -s https://raw.githubusercontent.com/taoyama/Add-NSG-Rule/master/nsg.sh \
| bash -s -- -g ResourceGroupName -n VMName
```
## Example
```bash
$ az group create --name testgroup --location japaneast > /dev/null
$ az vm create --resource-group testgroup --name testvm --image CentOS -o table
ResourceGroup    PowerState    PublicIpAddress    Fqdns    PrivateIpAddress    MacAddress         Location    Zones
---------------  ------------  -----------------  -------  ------------------  -----------------  ----------  -------
testgroup        VM running    xxx.xxx.xxx.xxx               10.0.0.4            00-0D-3A-CD-B0-29  japaneast
$ curl -s https://raw.githubusercontent.com/taoyama/Add-NSG-Rule/master/nsg.sh \
> | bash -s -- -g testgroup -n testvm
Source IP Address = xxx.xxx.xxx.xxx
AddressPrefix    Name          PrivateEndpointNetworkPolicies    PrivateLinkServiceNetworkPolicies    ProvisioningState
   ResourceGroup
---------------  ------------  --------------------------------  -----------------------------------  -------------------  ---------------
10.0.0.0/24      testvmSubnet  Enabled                           Enabled                              Succeeded
   testgroup
Access    DestinationAddressPrefix    DestinationPortRange    Direction    Name    Priority    Protocol    ProvisioningState    ResourceGroup    SourceAddressPrefix    SourcePortRange
--------  --------------------------  ----------------------  -----------  ------  ----------  ----------  -------------------  ---------------  ---------------------  -----------------
Allow     *                           22                      Inbound      SSH     100         *           Succeeded
        testgroup        xxx.xxx.xxx.xxx/32       *
Access    DestinationAddressPrefix    DestinationPortRange    Direction    Name    Priority    Protocol    ProvisioningState    ResourceGroup    SourceAddressPrefix    SourcePortRange
--------  --------------------------  ----------------------  -----------  ------  ----------  ----------  -------------------  ---------------  ---------------------  -----------------
Allow     *                           22                      Inbound      SSH     100         *           Succeeded
        testgroup        xxx.xxx.xxx.xxx/32       *
```