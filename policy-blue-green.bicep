param apimName string
param apiName string
param apiTags array
param apiBackends array
param loggerId string

var apiDisplayName = '${apiName}-APIs'
var apiPath = '${toLower(apiName)}-integrations'
var namedValuePrefix = '${toLower(apiName)}-apis'
/*
resource namedValueLive 'Microsoft.ApiManagement/service/namedValues@2020-12-01' = {
  name: '${apimName}/${namedValuePrefix}-live-color'
  properties: {
    displayName: '${namedValuePrefix}-live-color'
    value: 'blue'
    secret: false
    tags: concat(apiTags, ['live'])
  }
}

resource namedValueStaging 'Microsoft.ApiManagement/service/namedValues@2020-12-01' = {
  name: '${apimName}/${namedValuePrefix}-staging-color'
  properties: {
    displayName: '${namedValuePrefix}-staging-color'
    value: 'green'
    secret: false
    tags: concat(apiTags, ['staging'])
  }
}
*/
resource blueBackends 'Microsoft.ApiManagement/service/backends@2021-08-01' = [for backend in apiBackends: {
  name: '${apimName}/${backend.name}-blue'
  properties: {
    description: '${backend.name}-blue'
    url: backend.blueUrl
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}]

resource greeenBackends 'Microsoft.ApiManagement/service/backends@2021-08-01' = [for backend in apiBackends: {
  name: '${apimName}/${backend.name}-green'
  properties: {
    description: '${backend.name}-green'
    url: backend.greenUrl
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}]

resource api 'Microsoft.ApiManagement/service/apis@2020-12-01' = {
  name: '${apimName}/${apiPath}'
  properties: {
    displayName: apiDisplayName
    path: '/${apiPath}'
    apiRevision: '1'
    isCurrent: true
    subscriptionRequired: false
    protocols: [
      'https'
    ]
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2020-12-01' = {
  name: '${apimName}/${apiPath}/policy'
  dependsOn: [
    api
  ]
  properties: {
    format: 'xml'
    value: '<policies><inbound><base /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}

resource liveOperations 'Microsoft.ApiManagement/service/apis/operations@2020-12-01' = [for backend in apiBackends: {
  name: '${apimName}/${apiPath}/${backend.path}-live'
  dependsOn: [
    api
  ]
  properties: {
    displayName: '${backend.path} (Live)'
    urlTemplate: '/${backend.path}'
    method: 'POST'
  }
}]

resource liveOperationsPolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = [for backend in apiBackends: {
  name: '${apimName}/${apiPath}/${backend.path}-live/policy'
  dependsOn: [
    api
    liveOperations
  ]
  properties: {
    format: 'xml'
    value: '<policies><inbound><base /><set-backend-service backend-id="@(&quot;${backend.name}-{{${namedValuePrefix}-live-color}}&quot;)" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}]

resource stagingOperations 'Microsoft.ApiManagement/service/apis/operations@2020-12-01' = [for backend in apiBackends: {
  name: '${apimName}/${apiPath}/${backend.path}-staging'
  dependsOn: [
    api
  ]
  properties: {
    displayName: '${backend.path} (Staging)'
    urlTemplate: '/${backend.path}_Staging'
    method: 'POST'
  }
}]

resource stagingOperationsPolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = [for backend in apiBackends: {
  name: '${apimName}/${apiPath}/${backend.path}-staging/policy'
  dependsOn: [
    api
    stagingOperations
  ]
  properties: {
    format: 'xml'
    value: '<policies><inbound><base /><set-backend-service backend-id="@(&quot;${backend.name}-{{${namedValuePrefix}-staging-color}}&quot;)" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}]

resource diagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2021-08-01' = {
  name: '${apimName}/${apiPath}/applicationinsights'
  dependsOn: [
    api
  ]
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    logClientIp: true
    loggerId: loggerId
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
  }
}

resource apimAppInsightsDiagnosticsLoggers 'Microsoft.ApiManagement/service/apis/diagnostics/loggers@2018-01-01' = {
  name: '${apimName}/${apiPath}/applicationinsights/df-itsi-ai'
}
