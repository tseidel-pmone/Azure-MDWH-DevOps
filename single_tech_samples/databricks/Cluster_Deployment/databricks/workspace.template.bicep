@description('Specifies whether to deploy Azure Databricks workspace with Secure Cluster Connectivity (No Public IP) enabled or not.')
param disablePublicIp bool = false

@description('adbWorkspaceLocation for all resources.')
param adbWorkspaceLocation string = resourceGroup().location

@description('The name of the Azure Databricks workspace to create.')
param adbWorkspaceName string

@allowed([
  'standard'
  'premium'
])
@description('The pricing tier of workspace.')
param adbWorkspaceSkuTier string = 'standard'
param tagValues object

var managedResourceGroupName = 'databricks-rg-${adbWorkspaceName}-${uniqueString(adbWorkspaceName, resourceGroup().id)}'
var managedResourceGroupId = '${subscription().id}/resourceGroups/${managedResourceGroupName}'

resource adbWorkspaceName_resource 'Microsoft.Databricks/workspaces@2018-04-01' = {
  location: adbWorkspaceLocation
  name: adbWorkspaceName
  sku: {
    name: adbWorkspaceSkuTier
  }
  properties: {
    managedResourceGroupId: managedResourceGroupId
    parameters: {
      enableNoPublicIp: {
        value: disablePublicIp
      }
    }
  }
  tags: tagValues
  dependsOn: []
}

output databricks_workspace_name string = adbWorkspaceName
output databricks_location string = resourceGroup().location
output databricks_workspace_id string = adbWorkspaceName_resource.id
output databricks_workspace object = adbWorkspaceName_resource.properties