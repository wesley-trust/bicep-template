targetScope = 'resourceGroup'

// Common
@description('Azure region for the virtual network. Defaults to the current resource group location.')
param location string = resourceGroup().location

@description('Optional tags applied to the resources.')
param tags object = {}
var normalizedTags = empty(tags) ? null : tags

// Virtual Network
param virtualNetworkName string
param virtualNetworkResourceGroupName string
param subnetName string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  name: subnetName
  parent: virtualNetwork
}

// Service
@description('Flag to determine whether to deploy the service. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployServiceString string
var deployService = bool(deployServiceString)

// Resource
@description('Flag to determine whether to deploy the resource. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployResourceString string
var deployResource = bool(deployResourceString)

@description('Name of the resource to create.')
param resourceName string

module resource 'br/public:resource_module' = if (deployService && deployResource) {
  params: {
    name: resourceName
    location: location
    tags: normalizedTags
    subnetResourceId: subnet.id
  }
}
