// Azure Key Vault resource definition
param location string = 'East US'
param tenantId string = subscription().tenantId
param objectId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'call-center-kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: false
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: objectId
        permissions: {
          keys: ['all']
          secrets: ['all']
          certificates: ['all']
        }
      }
    ]
  }
}

output keyVaultName string = keyVault.name
