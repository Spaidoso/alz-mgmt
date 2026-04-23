metadata name = 'ALZ Workload - Runner Subnet'
metadata description = 'Creates a dedicated runner subnet and subnet NSG in the existing Online LZ VNet resource group.'

targetScope = 'resourceGroup'

@description('Required. Existing VNet name in this resource group.')
param parExistingVnetName string

@description('Required. Runner subnet name.')
param parRunnerSubnetName string

@description('Required. Runner subnet CIDR.')
param parRunnerSubnetPrefix string

@description('Required. NSG name for the runner subnet.')
param parRunnerNsgName string

@description('Required. Resource location.')
param parLocation string

@description('Optional. Tags applied to resources.')
param parTags object = {}

resource resExistingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: parExistingVnetName
}

resource resRunnerSubnetNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: parRunnerNsgName
  location: parLocation
  tags: parTags
  properties: {
    securityRules: [
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-AzureDns-Outbound-UDP'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureDNS'
        }
      }
      {
        name: 'Allow-AzureDns-Outbound-TCP'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureDNS'
        }
      }
      {
        name: 'Allow-Https-Outbound'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
      {
        name: 'Deny-All-Outbound'
        properties: {
          priority: 4096
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource resRunnerSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: resExistingVnet
  name: parRunnerSubnetName
  properties: {
    addressPrefix: parRunnerSubnetPrefix
    networkSecurityGroup: {
      id: resRunnerSubnetNsg.id
    }
  }
}

output outRunnerSubnetId string = resRunnerSubnet.id
