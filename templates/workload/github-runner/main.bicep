metadata name = 'ALZ Workload - Shared GitHub Runner Platform'
metadata description = 'Deploys a dedicated self-hosted GitHub Actions runner VM into the existing Online LZ VNet.'

targetScope = 'subscription'

@description('Required. Deployment locations.')
param parLocations array = [
  deployment().location
]

@description('Optional. The name of the runner resource group.')
param parRunnerResourceGroupName string = 'rg-alz-github-runner-${parLocations[0]}-001'

@description('Required. Existing resource group that contains the Online LZ VNet.')
param parExistingOnlineResourceGroupName string = 'spaidoso-lz-online-gameserver-rg'

@description('Required. Existing VNet name in the Online LZ resource group.')
param parExistingVnetName string = 'sfgameserver-vnet'

@description('Optional. Dedicated subnet name for the runner.')
param parRunnerSubnetName string = 'snet-github-runner'

@description('Optional. Dedicated subnet CIDR for the runner subnet.')
param parRunnerSubnetPrefix string = '10.0.1.0/24'

@description('Optional. Network security group name for the runner subnet.')
param parRunnerNsgName string = 'nsg-alz-github-runner-${parLocations[0]}-001'

@description('Optional. Runner VM name.')
param parRunnerVmName string = 'vm-alz-github-runner-${parLocations[0]}-001'

@description('Optional. Runner NIC name.')
param parRunnerNicName string = 'nic-alz-github-runner-${parLocations[0]}-001'

@description('Optional. Runner VM size.')
param parRunnerVmSize string = 'Standard_B2s'

@description('Required. Local admin username for the runner VM.')
param parRunnerAdminUsername string = 'alzrunneradmin'

@secure()
@description('Required for first deployment. Admin SSH public key for the runner VM.')
param parRunnerAdminSshPublicKey string

@description('Optional. GitHub organization URL for runner registration.')
param parGithubRunnerOrgUrl string = 'https://github.com/Spaidoso'

@description('Optional. GitHub runner group name.')
param parGithubRunnerGroup string = 'workload-runners'

@description('Optional. Prefix used to build the runner registration name.')
param parGithubRunnerNamePrefix string = 'alz-online'

@secure()
@description('Optional. Short-lived GitHub runner registration token. If empty, runner registration is skipped.')
param parGithubRunnerRegistrationToken string = ''

@description('Optional. Tags applied to created resources.')
param parTags object = {}

@description('Optional. OS image SKU for the runner VM.')
param parUbuntuSku string = '22_04-lts-gen2'

resource resRunnerResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: parRunnerResourceGroupName
  location: parLocations[0]
  tags: parTags
}

module modRunnerSubnet './subnetModule.bicep' = {
  name: 'modRunnerSubnet-${uniqueString(parExistingOnlineResourceGroupName, parRunnerSubnetName, parLocations[0])}'
  scope: resourceGroup(parExistingOnlineResourceGroupName)
  params: {
    parExistingVnetName: parExistingVnetName
    parRunnerSubnetName: parRunnerSubnetName
    parRunnerSubnetPrefix: parRunnerSubnetPrefix
    parRunnerNsgName: parRunnerNsgName
    parLocation: parLocations[0]
    parTags: parTags
  }
}

module modRunnerVm './runnerVm.bicep' = {
  name: 'modRunnerVm-${uniqueString(parRunnerResourceGroupName, parRunnerVmName, parLocations[0])}'
  scope: resourceGroup(parRunnerResourceGroupName)
  dependsOn: [
    resRunnerResourceGroup
  ]
  params: {
    parLocation: parLocations[0]
    parRunnerVmName: parRunnerVmName
    parRunnerNicName: parRunnerNicName
    parRunnerVmSize: parRunnerVmSize
    parRunnerAdminUsername: parRunnerAdminUsername
    parRunnerAdminSshPublicKey: parRunnerAdminSshPublicKey
    parRunnerSubnetId: modRunnerSubnet.outputs.outRunnerSubnetId
    parGithubRunnerOrgUrl: parGithubRunnerOrgUrl
    parGithubRunnerGroup: parGithubRunnerGroup
    parGithubRunnerNamePrefix: parGithubRunnerNamePrefix
    parGithubRunnerRegistrationToken: parGithubRunnerRegistrationToken
    parUbuntuSku: parUbuntuSku
    parTags: parTags
  }
}

output outRunnerVmResourceId string = modRunnerVm.outputs.outRunnerVmResourceId
output outRunnerVmPrincipalId string = modRunnerVm.outputs.outRunnerVmPrincipalId
output outRunnerSubnetId string = modRunnerSubnet.outputs.outRunnerSubnetId
