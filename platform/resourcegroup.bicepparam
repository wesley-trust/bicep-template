using './resourcegroup.bicep'

// Common
param location = '#{{ region }}'
param resourceGroupName = '#{{ resourceGroup }}'

param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}

// Service
param deployServiceString = '#{{ deployService }}'

// Resource Group
param deployResourceGroupString = '#{{ deployResourceGroup }}'
