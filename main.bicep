param envName string
param envHost string
param resourceName string
param apimSku string
param apimPublisherEmail string
param apimNamedValueFunctionUrlValue string
param apimNamedValueBaseUrlValue string
param apimNamedValueBaseUrlValue2 string
param apimNamedValueLdcRouterUrlValue string
param apimNamedValueEdcRouterUrlValue string
param apimBlueGreen array
param apimOAuth array

var location = resourceGroup().location

// Log Analytics Workspace
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${envName}-workspace'
  location: location
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery:'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing  = {
  name: '${envName}-itsi-ai'
  scope: resourceGroup('${envName}-func-rg')
}


// Azure API Management - Service
resource apim 'Microsoft.ApiManagement/service@2022-04-01-preview' = {
  name: resourceName
  location: location
  sku: {
    name: apimSku
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: 'NTT Ltd.'
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'false'
    }
  }
}

resource apimPolicy 'Microsoft.ApiManagement/service/policies@2022-04-01-preview' = {
  name: '${apim.name}/policy'
  properties:{
    format: 'xml'
    value: '<policies><inbound /><backend><forward-request timeout="240" /></backend><outbound /></policies>'
  }
}

resource apimLogging 'Microsoft.Insights/diagnosticSettings@2016-09-01' = {
  name: 'service'
  location: location
  scope: apim
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
      }
    ]
  }
}

resource apimAppInsightsLoggerConfig 'Microsoft.ApiManagement/service/namedValues@2022-04-01-preview' = {
  name: '${resourceName}/appInsightsInstrumentationKey'
  dependsOn: [
    apim
  ]
  properties: {
    displayName: 'appInsightsInstrumentationKey'
    value: appInsights.properties.InstrumentationKey
    secret: true
  }
}

resource apimAppInsightsLogger 'Microsoft.ApiManagement/service/loggers@2022-04-01-preview' = {
  name: '${resourceName}/df-itsi-ai'
  dependsOn: [
    apim
    apimAppInsightsLoggerConfig
  ]
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: '{{appInsightsInstrumentationKey}}'
    }
    isBuffered: true
    resourceId: appInsights.id
  }
}

resource apimAppInsightsDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2022-04-01-preview' = {
  name: '${resourceName}/applicationinsights'
  dependsOn: [
    apim
  ]
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'Legacy'
    verbosity: 'information'
    logClientIp: true
    loggerId: apimAppInsightsLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

resource apimAppInsightsDiagnosticsLoggers 'Microsoft.ApiManagement/service/diagnostics/loggers@2018-01-01' = {
  name: '${resourceName}/applicationinsights/df-itsi-ai'
}

// Azure API Management Policy - Function API
module apimFunctionsRouter './policy-generic.bicep' = {
  name: 'functions-policy'
  params: {
    apimName: apim.name
    apiName: 'function'
    apiDisplayName: 'Function'
    path: '/functions'
    backendName: 'snaplogic-function-url'
    backendUrl: apimNamedValueFunctionUrlValue
  }
}

// Azure API Management Policy - Generic API
module apimGenericRouter1 './policy-generic.bicep' = {
  name: 'generic-policy-1'
  params: {
    apimName: apim.name
    apiName: 'generic'
    apiDisplayName: 'Generic-1'
    path: ''
    backendName: 'snaplogic-base-url'
    backendUrl: apimNamedValueBaseUrlValue
  }
}

module apimGenericRouter2 './policy-generic.bicep' = {
  name: 'generic-policy-2'
  params: {
    apimName: apim.name
    apiName: 'generic-2'
    apiDisplayName: 'Generic-2'
    path: 'i2'
    backendName: 'snaplogic-base-url-2'
    backendUrl: apimNamedValueBaseUrlValue2
  }
}

// Azure API Management Policy - LDC Router
module apimLdcRouter './policy-router.bicep' = {
  name: 'ldc-router-module'
  params: {
    apimName: apim.name
    apiName: 'Router - LDC'
    path: 'ldc-router'
    backendUrl: apimNamedValueLdcRouterUrlValue
  }
}

// Azure API Management Policy - EDC Router
module apimEdcRouter './policy-router.bicep' = {
  name: 'edc-router-module'
  params: {
    apimName: apim.name
    apiName: 'Router - EDC'
    path: 'edc-router'
    backendUrl: apimNamedValueEdcRouterUrlValue
  }
}

// Azure API Management Policy - Blue/Green
module apimBlueGreenRoutes './policy-blue-green.bicep' = [for api in apimBlueGreen: {
  name: 'blue-green-module-${api.name}'
  params: {
    apimName: apim.name
    apiName: api.name
    apiTags: api.tags
    apiBackends: api.backends
    loggerId: apimAppInsightsLogger.id
  }
}]

// Azure API Management Policy - Blue/Green
module apimOAuthRoutes './policy-oauth.bicep' = {
  name: 'oauth-module'
  params: {
    envName: envName
    apimName: apim.name
    apimOAuth: apimOAuth
  }
}


// Azure Front Door - Service
resource frontDoor 'Microsoft.Network/frontDoors@2020-05-01' = {
  name: resourceName
  dependsOn: [
    apim
  ]
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
    friendlyName: resourceName
    frontendEndpoints: [
      {
        id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/FrontendEndpoints/${resourceName}-azurefd-net'
        name: '${resourceName}-azurefd-net'
        properties: {
          hostName: '${resourceName}.azurefd.net'
        }
      }
      {
        id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/FrontendEndpoints/${resourceName}-global-ntt'
        name: '${resourceName}-global-ntt'
        properties: {
          hostName: envHost
        }
      }
    ]
    backendPools: [
      {
        id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/BackendPools/${resourceName}'
        name: resourceName
        properties: {
          backends: [
            {
              address: '${resourceName}.azure-api.net'
              backendHostHeader: '${resourceName}.azure-api.net'
              httpPort: 80
              httpsPort: 443
              priority: 1
              weight: 50
              enabledState: 'Enabled'
            }
          ]
          loadBalancingSettings: {
            id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/LoadBalancingSettings/loadBalancingSettings-1616733930202'
          }
          healthProbeSettings: {
            id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/HealthProbeSettings/healthProbeSettings-1616733930202'
          }
        }
      }
    ]
    backendPoolsSettings: {
      enforceCertificateNameCheck: 'Enabled'
      sendRecvTimeoutSeconds: 240
    }
    routingRules: [
      {
        name: resourceName
        properties: {
          acceptedProtocols: [
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          enabledState: 'Enabled'
          frontendEndpoints: [
            {
              id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/FrontendEndpoints/${resourceName}-azurefd-net'
            }
            {
              id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/FrontendEndpoints/${resourceName}-global-ntt'
            }
          ]
          routeConfiguration: {
            forwardingProtocol: 'HttpsOnly'
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            backendPool: {
              id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/BackendPools/${resourceName}'
            }
          }
        }
      }
    ]
    loadBalancingSettings: [
      {
        id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/LoadBalancingSettings/loadBalancingSettings-1616733930202'
        name: 'loadBalancingSettings-1616733930202'
        properties: {
          additionalLatencyMilliseconds: 0
          sampleSize: 4
          successfulSamplesRequired: 2
        }
      }
    ]
    healthProbeSettings: [
      {
        id: '${resourceId('Microsoft.Network/frontdoors', resourceName)}/HealthProbeSettings/healthProbeSettings-1616733930202'
        name: 'healthProbeSettings-1616733930202'
        properties: {
          intervalInSeconds: 30
          path: '/'
          protocol: 'Https'
          enabledState: 'Disabled'
          healthProbeMethod: 'HEAD'
        }
      }
    ]
  }
}

resource frontDoorLogging 'Microsoft.Insights/diagnosticSettings@2016-09-01' = {
  name: 'service'
  location: location
  scope: frontDoor
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'FrontdoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontdoorWebApplicationFirewallLog'
        enabled: true
      }
    ]
  }
}
