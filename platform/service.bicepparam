using './service.bicep'

// Common
param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}

// Service
param deployServiceString = '#{{ deployService }}'

// Virtual Network
param virtualNetworkName = '#{{ vnet-001-name }}'
param subnetName = '#{{ snet-001-name }}'
param virtualNetworkResourceGroupName = '#{{ networkResourceGroup }}'

// Resource
param deployResourceString = '#{{ deployResource }}'
param resourceName = '#{{ resourceAbbreviation-001-name }}'
