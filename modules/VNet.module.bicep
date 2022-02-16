param name string
param region string
param tags object

param vnetAddressSpace string 
param enableVmProtection bool = false
param enableDdosProtection bool = false
param snetApim object
param snetDefault object
param nsgId string



@description('Service Endpoints enabled on the APIM subnet')
param apimSubnetServiceEndpoints array = [
  {
    service: 'Microsoft.Storage'
  }
  {
    service: 'Microsoft.Sql'
  }
  {
    service: 'Microsoft.EventHub'
  }
]


resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: name
  location: region
  tags: tags
  properties: {
    enableVmProtection: enableVmProtection
    enableDdosProtection: enableDdosProtection
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }      
    subnets:[
      {
        name: snetDefault.name
        properties: {
          addressPrefix: snetDefault.subnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: snetApim.name
        properties: {
          addressPrefix: snetApim.subnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: nsgId
          }
          serviceEndpoints: apimSubnetServiceEndpoints
        }
      }      
    ]
  }  
}


output vnetID string = vnet.id
output vnetName string = vnet.name
output snetDefaultID string = vnet.properties.subnets[0].id
output snetApimID string = vnet.properties.subnets[1].id
