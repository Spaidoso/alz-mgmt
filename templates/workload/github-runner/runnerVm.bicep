metadata name = 'ALZ Workload - Runner VM'
metadata description = 'Creates the dedicated GitHub self-hosted runner VM in the runner resource group.'

targetScope = 'resourceGroup'

@description('Required. Resource location.')
param parLocation string

@description('Required. Runner VM name.')
param parRunnerVmName string

@description('Required. Runner NIC name.')
param parRunnerNicName string

@description('Required. Runner VM size.')
param parRunnerVmSize string

@description('Required. Local admin username for the runner VM.')
param parRunnerAdminUsername string

@secure()
@description('Required. Admin SSH public key for the runner VM.')
param parRunnerAdminSshPublicKey string

@description('Required. Runner subnet resource ID.')
param parRunnerSubnetId string

@description('Optional. GitHub organization URL for runner registration.')
param parGithubRunnerOrgUrl string

@description('Optional. GitHub runner group name.')
param parGithubRunnerGroup string

@description('Optional. Prefix used to build the runner registration name.')
param parGithubRunnerNamePrefix string

@secure()
@description('Optional. Short-lived GitHub runner registration token. If empty, runner registration is skipped.')
param parGithubRunnerRegistrationToken string = ''

@description('Optional. OS image SKU for the runner VM.')
param parUbuntuSku string = '22_04-lts-gen2'

@description('Optional. Tags applied to resources.')
param parTags object = {}

resource resRunnerNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: parRunnerNicName
  location: parLocation
  tags: parTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: parRunnerSubnetId
          }
        }
      }
    ]
  }
}

var varRunnerVersion = '2.317.0'
var varRunnerBootstrapLines = [
  '#!/bin/bash'
  'set -euo pipefail'
  ''
  'apt-get update -y'
  'apt-get install -y curl jq unzip ca-certificates'
  ''
  'id -u actions >/dev/null 2>&1 || useradd -m -s /bin/bash actions'
  'mkdir -p /opt/actions-runner'
  'chown -R actions:actions /opt/actions-runner'
  ''
  'TOKEN="${parGithubRunnerRegistrationToken}"'
  ''
  'if [ -z "$TOKEN" ]; then'
  '  echo "No GitHub registration token provided. Skipping runner registration."'
  '  exit 0'
  'fi'
  ''
  'su - actions -c "cd /opt/actions-runner && curl -fsSL -o actions-runner.tar.gz https://github.com/actions/runner/releases/download/v${varRunnerVersion}/actions-runner-linux-x64-${varRunnerVersion}.tar.gz"'
  'su - actions -c "cd /opt/actions-runner && tar xzf actions-runner.tar.gz"'
  'su - actions -c "cd /opt/actions-runner && ./config.sh --url ${parGithubRunnerOrgUrl} --token $TOKEN --runnergroup ${parGithubRunnerGroup} --name ${parGithubRunnerNamePrefix}-$(hostname) --labels workload-runners,online-lz --unattended --replace"'
  'cd /opt/actions-runner'
  './svc.sh install actions'
  './svc.sh start'
]
var varRunnerBootstrap = join(varRunnerBootstrapLines, '\n')

resource resRunnerVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: parRunnerVmName
  location: parLocation
  identity: {
    type: 'SystemAssigned'
  }
  tags: parTags
  properties: {
    hardwareProfile: {
      vmSize: parRunnerVmSize
    }
    osProfile: {
      computerName: parRunnerVmName
      adminUsername: parRunnerAdminUsername
      customData: base64(varRunnerBootstrap)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${parRunnerAdminUsername}/.ssh/authorized_keys'
              keyData: parRunnerAdminSshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: parUbuntuSku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resRunnerNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

output outRunnerVmResourceId string = resRunnerVm.id
output outRunnerVmPrincipalId string = resRunnerVm.identity.principalId
