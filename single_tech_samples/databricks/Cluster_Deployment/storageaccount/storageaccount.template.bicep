@minLength(3)
@maxLength(24)
@description('Name of the storage account')
param storageAccountName string

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Premium_LRS'
])
@description('Storage Account Sku')
param storageAccountSku string = 'Standard_LRS'

@allowed([
  'Standard'
  'Premium'
])
@description('Storage Account Sku tier')
param storageAccountSkuTier string = 'Premium'

@description('Location for all resources.')
param storageAccountLocation string = resourceGroup().location

@description('Enable or disable Blob encryption at Rest.')
param encryptionEnabled bool = true

resource storageAccountName_resource 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  tags: {
    displayName: storageAccountName
    type: 'Storage'
  }
  location: storageAccountLocation
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: encryptionEnabled
        }
        file: {
          enabled: encryptionEnabled
        }
      }
    }
  }
  sku: {
    name: storageAccountSku
    tier: storageAccountSkuTier
  }
}