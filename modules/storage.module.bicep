param region string
param name string
param tags object = {}
param kind string = 'StorageV2'
param sku object = {
  name: 'Standard_LRS'
  tier: 'Standard'
}

resource storage 'Microsoft.Storage/storageAccounts@2019-06-01' = {  
  name: length(name) > 24 ? toLower(substring(replace(name, '-', ''), 0, 24)) : toLower(replace(name, '-', ''))
  location: region  
  kind: kind
  sku: sku
  tags: union(tags, {
    displayName: name
  })  
  properties: {
    accessTier: 'Hot'
    largeFileSharesState: 'Enabled'
    supportsHttpsTrafficOnly: true
  }  
}

output id string = storage.id
output name string = storage.name
output primaryKey string = listKeys(storage.id, storage.apiVersion).keys[0].value
output primaryEndpoints object = storage.properties.primaryEndpoints
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${name};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'
