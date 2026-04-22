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
param parRunnerVmSize = 'Standard_B2s'
param parRunnerAdminUsername = 'alzrunneradmin'

// Set at deployment time (via secured pipeline variables / parameter override).
param parRunnerAdminSshPublicKey = ''
param parGithubRunnerRegistrationToken = ''

param parGithubRunnerOrgUrl = 'https://github.com/Spaidoso'
param parGithubRunnerGroup = 'workload-runners'
param parGithubRunnerNamePrefix = 'alz-online'
param parUbuntuSku = '22_04-lts-gen2'

param parTags = {
  alzModule: 'workload-github-runner'
  environment: 'online-lz'
}
