using './main.bicep'

param parLocations = [
  'westus2'
]

param parRunnerResourceGroupName = 'rg-alz-github-runner-${parLocations[0]}-001'
param parExistingOnlineResourceGroupName = 'spaidoso-lz-online-gameserver-rg'
param parExistingVnetName = 'sfgameserver-vnet'
param parRunnerSubnetName = 'snet-github-runner'
param parRunnerSubnetPrefix = '10.0.1.0/24'
param parRunnerNsgName = 'nsg-alz-github-runner-${parLocations[0]}-001'
param parRunnerVmName = 'vm-alz-github-runner-${parLocations[0]}-001'
param parRunnerNicName = 'nic-alz-github-runner-${parLocations[0]}-001'
param parRunnerKeyVaultName = 'kv-alz-github-runner-${parLocations[0]}-001'
param parRunnerKeyVaultPrivateEndpointName = 'pep-alz-github-runner-kv-${parLocations[0]}-001'
param parRunnerKeyVaultPrivateDnsZoneGroupName = 'default'
param parRunnerKeyVaultPublicNetworkAccess = 'Disabled'
param parRunnerKeyVaultPrivateDnsZoneId = '/subscriptions/82ce8884-3284-4808-b77e-8dd9b0175d4c/resourceGroups/rg-alz-dns-${parLocations[0]}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
param parRunnerVmSize = 'Standard_B2s'
param parRunnerAdminUsername = 'alzrunneradmin'

// Set at deployment time (via secured pipeline variables / parameter override).
param parRunnerAdminSshPublicKey = ''
param parGithubRunnerRegistrationToken = ''

param parGithubRunnerOrgUrl = 'https://github.com/Spaidoso'
param parGithubRunnerGroup = 'workload-runners'
param parGithubRunnerNamePrefix = 'alz-online'
param parUbuntuSku = '22_04-lts-gen2'
param parRunnerSshSecretNames = {
  public: 'ssh-public'
  private: 'ssh-private'
}

param parTags = {
  alzModule: 'workload-github-runner'
  environment: 'online-lz'
}
