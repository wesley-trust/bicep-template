targetScope = 'subscription'

// Common
@description('Flag to determine whether to deploy the Resource Group. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployResourceGroupString string
var deployResourceGroup = bool(deployResourceGroupString)

param location string
param resourceGroupName string

@description('Optional tags applied to the resource group.')
param tags object = {}
var normalizedTags = empty(tags) ? null : tags

// Service
@description('Flag to determine whether to deploy the service. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployServiceString string
var deployService = bool(deployServiceString)

// Resource Group
module resourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = if (deployService && deployResourceGroup) {
  params: {
    name: resourceGroupName
    location: location
    tags: normalizedTags
  }
}
