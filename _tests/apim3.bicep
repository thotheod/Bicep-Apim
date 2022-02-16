@description('This will be used to derive names for all of your resources')
param base_name string

@description('The resource ID for an existing Log Analytics workspace')
param log_analytics_workspace_id string

@description('Location in which resources will be created')
param location string = resourceGroup().location

@description('The edition of Azure API Management to use. This must be an edition that supports VNET Integration. This selection can have a significant impact on consumption cost and \'Developer\' is recommended for non-production use.')
@allowed([
  'Developer'
  'Premium'
])
param apim_sku string = 'Developer'

@description('The number of Azure API Management capacity units to provision. For Developer edition, this must equal 1.')
param apim_capacity int = 1

@description('The number of Azure Application Gateway capacity units to provision. This setting has a direct impact on consumption cost and is recommended to be left at the default value of 1')
param app_gateway_capacity int = 1

@description('The address space (in CIDR notation) to use for the VNET to be deployed in this solution. If integrating with other networked components, there should be no overlap in address space.')
param vnet_address_prefix string = '10.0.0.0/16'

@description('The address space (in CIDR notation) to use for the subnet to be used by Azure Application Gateway. Must be contained in the VNET address space.')
param app_gateway_subnet_prefix string = '10.0.0.0/24'

@description('The address space (in CIDR notation) to use for the subnet to be used by Azure API Management. Must be contained in the VNET address space.')
param apim_subnet_prefix string = '10.0.1.0/24'

@description('Descriptive name for publisher to be used in the portal')
param apim_publisher_name string = 'Contoso'

@description('Email adddress associated with publisher')
param apim_publisher_email string = 'api@contoso.com'

var app_insights_name_var = '${base_name}-ai'
var vnet_name_var = '${base_name}-vnet'
var apim_name_var = '${base_name}-apim'
var public_ip_name_var = '${base_name}-pip'
var app_gateway_name_var = '${base_name}-agw'
var vnet_dns_link_name = '${base_name}-vnet-dns-link'

resource apim_name 'Microsoft.ApiManagement/service@2020-12-01' = {
  name: apim_name_var
  location: location
  sku: {
    name: apim_sku
    capacity: apim_capacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherName: apim_publisher_name
    publisherEmail: apim_publisher_email
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet_name_var, 'apimSubnet')
    }
  }
  dependsOn: [
    vnet_name
  ]
}

resource apim_name_my_gateway 'Microsoft.ApiManagement/service/gateways@2020-12-01' = {
  parent: apim_name
  name: 'my-gateway'
  properties: {
    locationData: {
      name: 'My internal location'
    }
    description: 'Self hosted gateway bringing API Management to the edge'
  }
}

resource apim_name_AppInsightsLogger 'Microsoft.ApiManagement/service/loggers@2020-12-01' = {
  parent: apim_name
  name: 'AppInsightsLogger'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: app_insights_name.id
    credentials: {
      instrumentationKey: app_insights_name.properties.InstrumentationKey
    }
  }
}

resource apim_name_applicationinsights 'Microsoft.ApiManagement/service/diagnostics@2020-12-01' = {
  parent: apim_name
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'Legacy'
    verbosity: 'information'
    logClientIp: true
    loggerId: apim_name_AppInsightsLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        body: {
          bytes: 0
        }
      }
      response: {
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        body: {
          bytes: 0
        }
      }
      response: {
        body: {
          bytes: 0
        }
      }
    }
  }
}

resource Microsoft_Insights_diagnosticSettings_logToAnalytics 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  scope: apim_name
  name: 'logToAnalytics'
  location: location
  properties: {
    workspaceId: log_analytics_workspace_id
    logs: [
      {
        category: 'GatewayLogs'
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

resource app_gateway_name 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: app_gateway_name_var
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: app_gateway_capacity
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet_name_var, 'appGatewaySubnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: public_ip_name.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'gatewayBackEnd'
        properties: {
          backendAddresses: [
            {
              fqdn: '${apim_name_var}.azure-api.net'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'apim-gateway-https-setting'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: '${apim_name_var}.azure-api.net'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', app_gateway_name_var, 'apim-gateway-probe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'apim-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontEndIPConfigurations', app_gateway_name_var, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontEndPorts', app_gateway_name_var, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'apim-routing-rule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', app_gateway_name_var, 'apim-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', app_gateway_name_var, 'gatewayBackEnd')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', app_gateway_name_var, 'apim-gateway-https-setting')
          }
        }
      }
    ]
    probes: [
      {
        name: 'apim-gateway-probe'
        properties: {
          protocol: 'Https'
          host: '${apim_name_var}.azure-api.net'
          port: 443
          path: '/status-0123456789abcdef'
          interval: 30
          timeout: 120
          unhealthyThreshold: 8
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
  }
  dependsOn: [
    app_insights_name

    vnet_name
    azure_api_net
  ]
}

resource Microsoft_Insights_diagnosticSettings_logToAnalytics 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  scope: app_gateway_name
  name: 'logToAnalytics'
  location: location
  properties: {
    workspaceId: log_analytics_workspace_id
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
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

resource app_insights_name 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: app_insights_name_var
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: log_analytics_workspace_id
  }
}

resource public_ip_name 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: public_ip_name_var
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: base_name
    }
  }
}

resource vnet_name 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnet_name_var
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_address_prefix
      ]
    }
    subnets: [
      {
        type: 'subnets'
        name: 'appGatewaySubnet'
        properties: {
          addressPrefix: app_gateway_subnet_prefix
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
              locations: [
                '*'
              ]
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        type: 'subnets'
        name: 'apimSubnet'
        properties: {
          addressPrefix: apim_subnet_prefix
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
              locations: [
                '*'
              ]
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource azure_api_net 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'azure-api.net'
  location: 'global'
  properties: {}
  dependsOn: [
    apim_name
    vnet_name
  ]
}

resource azure_api_net_apim_name 'Microsoft.Network/privateDnsZones/A@2018-09-01' = if (true) {
  parent: azure_api_net
  name: apim_name_var
  location: 'global'
  properties: {
    ttl: 36000
    aRecords: [
      {
        ipv4Address: apim_name.properties.privateIPAddresses[0]
      }
    ]
  }
}

resource azure_api_net_vnet_dns_link_name 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: azure_api_net
  name: vnet_dns_link_name
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnet_name.id
    }
  }
}

output publicEndpointFqdn string = public_ip_name.properties.dnsSettings.fqdn