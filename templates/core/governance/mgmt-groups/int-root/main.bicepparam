using './main.bicep'

// General Parameters
param parLocations = [
  'westus2'
  ''
]
param parEnableTelemetry = true

param intRootConfig = {
  createOrUpdateManagementGroup: true
  managementGroupName: 'alz'
  managementGroupParentId: '4d00acda-e258-43e1-bd90-9370a4d118e1'
  managementGroupDisplayName: 'Azure Landing Zones'
  managementGroupDoNotEnforcePolicyAssignments: []
  managementGroupExcludedPolicyAssignments: []
  customerRbacRoleDefs: []
  customerRbacRoleAssignments: []
  customerPolicyDefs: []
  customerPolicySetDefs: []
  customerPolicyAssignments: []
  subscriptionsToPlaceInManagementGroup: []
  waitForConsistencyCounterBeforeCustomPolicyDefinitions: 10
  waitForConsistencyCounterBeforeCustomPolicySetDefinitions: 10
  waitForConsistencyCounterBeforeCustomRoleDefinitions: 10
  waitForConsistencyCounterBeforePolicyAssignments: 40
  waitForConsistencyCounterBeforeRoleAssignments: 40
  waitForConsistencyCounterBeforeSubPlacement: 10
}

// Only specify the parameters you want to override - others will use defaults from JSON files
param parPolicyAssignmentParameterOverrides = {
  'Deploy-MDFC-Config-H224': {
    parameters: {
      logAnalytics: {
        value: '/subscriptions/e4fdb784-0635-495b-9d34-e57009b5eb57/resourcegroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.OperationalInsights/workspaces/law-alz-${parLocations[0]}'
      }
      emailSecurityContact: {
        value: 'security@yourcompany.com'
      }
      ascExportResourceGroupName: {
        value: 'rg-alz-asc-${parLocations[0]}'
      }
      ascExportResourceGroupLocation: {
        value: parLocations[0]
      }
    }
  }
  'Deploy-AzActivity-Log': {
    parameters: {
      logAnalytics: {
        value: '/subscriptions/e4fdb784-0635-495b-9d34-e57009b5eb57/resourcegroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.OperationalInsights/workspaces/law-alz-${parLocations[0]}'
      }
      logsEnabled: {
        value: 'True'
      }
    }
  }
  'Deploy-Diag-LogsCat': {
    parameters: {
      logAnalytics: {
        value: '/subscriptions/e4fdb784-0635-495b-9d34-e57009b5eb57/resourcegroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.OperationalInsights/workspaces/law-alz-${parLocations[0]}'
      }
    }
  }
  'Deploy-SvcHealth-BuiltIn': {
    parameters: {
      resourceGroupLocation: {
        value: parLocations[0]
      }
      actionGroupResources: {
        value: {
          actionGroupEmail: ['triage@yourcompany.com']
          eventHubResourceId: []
          functionResourceId: ''
          functionTriggerUrl: ''
          logicappCallbackUrl: ''
          logicappResourceId: ''
          webhookServiceUri: []
        }
      }
    }
  }
  'Deploy-AzSqlDb-Auditing': {
    parameters: {
      logAnalyticsWorkspaceResourceId: {
        value: '/subscriptions/e4fdb784-0635-495b-9d34-e57009b5eb57/resourcegroups/rg-alz-logging-${parLocations[0]}/providers/Microsoft.OperationalInsights/workspaces/law-alz-${parLocations[0]}'
      }
    }
  }
}
