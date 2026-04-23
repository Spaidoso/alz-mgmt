metadata name = 'ALZ Workload - Runner Key Vault'
metadata description = 'Creates the dedicated Key Vault, private endpoint, and runner MI RBAC for shared runner SSH material.'

targetScope = 'resourceGroup'

@description('Required. Resource location.')
param parLocation string

@description('Required. Key Vault name.')
param parRunnerKeyVaultName string

@description('Required. Private endpoint name for the runner Key Vault.')
param parRunnerKeyVaultPrivateEndpointName string

@description('Optional. Private DNS zone group name for the runner Key Vault private endpoint.')
param parRunnerKeyVaultPrivateDnsZoneGroupName string = 'default'

@description('Optional. Public network access mode for the runner Key Vault.')
param parRunnerKeyVaultPublicNetworkAccess string = 'Disabled'

@description('Required. Resource ID of the existing private DNS zone for Key Vault private endpoints.')
param parRunnerKeyVaultPrivateDnsZoneId string

@description('Required. Resource ID of the runner subnet that hosts the VM and Key Vault private endpoint.')
param parRunnerSubnetId string

@description('Required. Principal ID of the runner VM managed identity.')
param parRunnerVmPrincipalId string

@description('Optional. Secret names reserved for the runner SSH keypair.')
param parRunnerSshSecretNames object = {
  public: 'ssh-public'
  private: 'ssh-private'
}

@description('Optional. Tags applied to created resources.')
param parTags object = {}

var varKeyVaultSecretsUserRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource resRunnerKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: parRunnerKeyVaultName
  location: parLocation
  tags: union(parTags, {
    runnerSshPublicKeySecretName: string(parRunnerSshSecretNames.public)
    runnerSshPrivateKeySecretName: string(parRunnerSshSecretNames.private)
  })
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: parRunnerKeyVaultPublicNetworkAccess
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }
}

resource resRunnerKeyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: parRunnerKeyVaultPrivateEndpointName
  location: parLocation
  tags: parTags
  properties: {
    subnet: {
      id: parRunnerSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${parRunnerKeyVaultName}-vault'
        properties: {
          privateLinkServiceId: resRunnerKeyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource resRunnerKeyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: resRunnerKeyVaultPrivateEndpoint
  name: parRunnerKeyVaultPrivateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vaultcore'
        properties: {
          privateDnsZoneId: parRunnerKeyVaultPrivateDnsZoneId
        }
      }
    ]
  }
}

resource resRunnerVmKeyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resRunnerKeyVault.id, parRunnerVmPrincipalId, varKeyVaultSecretsUserRoleDefinitionId)
  scope: resRunnerKeyVault
  properties: {
    roleDefinitionId: varKeyVaultSecretsUserRoleDefinitionId
    principalId: parRunnerVmPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Allows the shared GitHub runner VM managed identity to read SSH key secrets from the runner Key Vault.'
  }
}

output outRunnerKeyVaultId string = resRunnerKeyVault.id
output outRunnerKeyVaultName string = resRunnerKeyVault.name
output outRunnerKeyVaultUri string = resRunnerKeyVault.properties.vaultUri
output outRunnerKeyVaultPrivateEndpointId string = resRunnerKeyVaultPrivateEndpoint.id
