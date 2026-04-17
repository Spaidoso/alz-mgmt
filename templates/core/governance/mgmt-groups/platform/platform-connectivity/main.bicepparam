using './main.bicep'

// General Parameters
param parLocations = [
  'westus2'
  ''
]
param parEnableTelemetry = true

param platformConnectivityConfig = {
  createOrUpdateManagementGroup: true
  managementGroupName: 'connectivity'
  managementGroupParentId: 'platform'
  managementGroupIntermediateRootName: 'alz'
  managementGroupDisplayName: 'Connectivity'
  managementGroupDoNotEnforcePolicyAssignments: []
  managementGroupExcludedPolicyAssignments: []
  customerRbacRoleDefs: []
  customerRbacRoleAssignments: []
  customerPolicyDefs: []
  customerPolicySetDefs: []
  customerPolicyAssignments: []
  subscriptionsToPlaceInManagementGroup: ['82ce8884-3284-4808-b77e-8dd9b0175d4c']
  waitForConsistencyCounterBeforeCustomPolicyDefinitions: 10
  waitForConsistencyCounterBeforeCustomPolicySetDefinitions: 10
  waitForConsistencyCounterBeforeCustomRoleDefinitions: 10
  waitForConsistencyCounterBeforePolicyAssignments: 40
  waitForConsistencyCounterBeforeRoleAssignments: 40
  waitForConsistencyCounterBeforeSubPlacement: 10
}

// Only specify the parameters you want to override - others will use defaults from JSON files
param parPolicyAssignmentParameterOverrides = {
  'Enable-DDoS-VNET': {
    parameters: {
      ddosPlan: {
        value: '/subscriptions/82ce8884-3284-4808-b77e-8dd9b0175d4c/resourceGroups/rg-alz-conn-${parLocations[0]}/providers/Microsoft.Network/ddosProtectionPlans/ddos-alz-${parLocations[0]}'
      }
    }
  }
}
