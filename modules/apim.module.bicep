param name string
param region string
param tags object

@description('The name of the owner of the service')
@minLength(1)
param organizationName string

@description('The email address of the owner of the service')
@minLength(1)
param organizationEmail string

@description('The pricing tier of this API Management service')
@allowed([
  'Developer'
  'Standard'
  'Premium'
])
param sku string = 'Developer'

// @description('Zone numbers e.g. 1,2,3.')
// param availabilityZones array = [
//   '1'
//   '2'
// ]

@description('Type of VPN in which the APIM will be deployed in')
@allowed([
  'None'
  'External'
  'Internal'
])
param virtualNetworkType string = 'External'

@description('ID of the public IPv4 - standard SKU. Available only in Developer and premium SKU')
param pipStandardId string

@description('Subnet ID of the network where the APIM will be deployed (dedicated?)')
param snetAPIMId string

@description('The application insights instrumentationKey')
param appInsightsInstrumentationKey string

param appInsightsId string
param logAnalyticsWsId string


resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: name
  location: region
  tags: tags
  sku: {
    name: sku
    capacity: 1
  }
  properties: {
    publisherName: organizationName
    publisherEmail: organizationEmail
    virtualNetworkType: virtualNetworkType
    publicIpAddressId: pipStandardId
    virtualNetworkConfiguration: {
      subnetResourceId: snetAPIMId
    }
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'false'
    }
  }
  // zones: ((length(availabilityZones) == 0) ? [] : availabilityZones)
}


resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2021-08-01' = {
  parent: apim
  name: 'AppInsightsLogger'
  //name: '${apim.name}/exampleLogger'
  properties: {
    loggerType: 'applicationInsights'
    description: 'appInsightsLogger'
    resourceId: appInsightsId
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
  }
}

resource logToAnalytics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apim
  name: 'logToAnalytics'
  location: region
  properties: {
    workspaceId: logAnalyticsWsId
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
      }
      {
        category: 'WebSocketConnectionLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// resource petStoreApiExample 'Microsoft.ApiManagement/service/apis@2020-06-01-preview' = {
//   name: '${apim.name}/PetStoreSwaggerImport'
//   properties: {
//     format: 'swagger-link-json'
//     value: 'http://petstore.swagger.io/v2/swagger.json'
//     path: 'examplepetstore'
//   }
// }

// resource randomColorsApi 'Microsoft.ApiManagement/service/apis@2020-06-01-preview' = {
//   name: '${apim.name}/ColorsSwaggerImport'
//   properties: {
//     format: 'swagger-link-json'
//     value: 'https://markcolorapi.azurewebsites.net/swagger/v1/swagger.json.'
//     path: 'colors'    
//   }
// }

resource apimSelfHostedGateway 'Microsoft.ApiManagement/service/gateways@2021-08-01' = {
  parent: apim
  name: 'my-gateway'
  properties: {
    locationData: {
      name: 'My internal location'
    }
    description: 'Self hosted gateway bringing API Management to the edge'
  }
}
