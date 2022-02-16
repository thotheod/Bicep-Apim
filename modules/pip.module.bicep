param name string
param region string
param tags object

@description('SKU for the Public IP used to access the api management service.')
@allowed([
  'Basic'
  'Standard'
])
param publicIpSku string = 'Standard'


@description('Allocation method of pip.')
@allowed([
  'Dynamic'
  'Static'
])
param publicIPAllocationMethod string = 'Static'

@description('Unique DNS Name for the Public IP used to access the api management service.')
param dnsLabelPrefix string = toLower('${name}-${uniqueString(resourceGroup().id)}')


resource pip 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: name
  location: region
  tags: tags
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}


output id string = pip.id
