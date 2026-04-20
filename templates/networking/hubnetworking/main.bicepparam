using './main.bicep'

// General Parameters
param parLocations = [
  'westus2'
]
param parGlobalResourceLock = {
  name: 'GlobalResourceLock'
  kind: 'None'
  notes: 'This lock was created by the ALZ Bicep Accelerator.'
}
param parTags = {}
param parEnableTelemetry = true

// Resource Group Parameters
param parHubNetworkingResourceGroupNamePrefix = 'rg-alz-conn'
param parDnsResourceGroupNamePrefix = 'rg-alz-dns'
param parDnsPrivateResolverResourceGroupNamePrefix = 'rg-alz-dnspr'

// Hub Networking Parameters
param hubNetworks = [
  {
    name: 'vnet-alz-${parLocations[0]}'
    location: parLocations[0]
    addressPrefixes: [
      '10.0.0.0/22'
    ]
    deployPeering: false
    dnsServers: []
    peeringSettings: []
    subnets: [
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.0.128/27'
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.0.0.0/26'
      }
      {
        name: 'AzureFirewallManagementSubnet'
        addressPrefix: '10.0.0.192/26'
      }
    ]
    azureFirewallSettings: {
      deployAzureFirewall: true
      azureFirewallName: 'afw-alz-${parLocations[0]}'
      azureSkuTier: 'Basic'
      zones: []  // Basic SKU doesn't support availability zones
      publicIPAddressObject: {
        name: 'pip-afw-alz-${parLocations[0]}'
      }
      managementIPAddressObject: {
        name: 'pip-afw-mgmt-alz-${parLocations[0]}'
      }
    }
    bastionHostSettings: {
      deployBastion: false
    }
    vpnGatewaySettings: {
      deployVpnGateway: true
      name: 'vgw-alz-${parLocations[0]}'
      skuName: 'VpnGw1AZ'
      vpnMode: 'activePassiveNoBgp'
      vpnType: 'RouteBased'
      publicIpZones: []
    }
    expressRouteGatewaySettings: {
      deployExpressRouteGateway: false
    }
    privateDnsSettings: {
      deployPrivateDnsZones: true
      deployDnsPrivateResolver: false
      privateDnsZones: []
    }
    ddosProtectionPlanSettings: {
      deployDdosProtectionPlan: false
    }
  }
]
