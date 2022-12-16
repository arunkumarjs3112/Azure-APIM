param envName string
param apimName string
param apimOAuth array

resource apimRouterNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-04-01-preview' = [for api in apimOAuth: {
  name: '${apimName}/kv-${api.vaultKey}'
  properties: {
    displayName: 'kv-${api.vaultKey}'
    keyVault: {
      secretIdentifier: 'https://${envName}-credentials-kv${environment().suffixes.keyvaultDns}/secrets/${api.vaultKey}'
    }
    secret: true
  }
}]

resource apimRouter 'Microsoft.ApiManagement/service/apis@2022-04-01-preview' = {
  name: '${apimName}/oauth'
  properties: {
    displayName: 'OAuth'
    path: 'oauth'
    apiRevision: '1'
    isCurrent: true
    subscriptionRequired: false
    protocols: [
      'https'
    ]
  }
}

resource apimRouterPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-04-01-preview' = {
  name: '${apimName}/oauth/policy'
  dependsOn: [
    apimRouter
  ]
  properties:{
    format: 'xml'
    value: '<policies><inbound><base /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}

resource apimRouterOperation 'Microsoft.ApiManagement/service/apis/operations@2022-04-01-preview' = [for api in apimOAuth: {
  name: '${apimName}/oauth/${api.name}'
  dependsOn: [
    apimRouter
  ]
  properties:{
    displayName: api.name
    method: 'POST'
    urlTemplate: api.path
  }
}]

resource apimRouterOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-04-01-preview' = [for api in apimOAuth: {
  name: '${apimName}/oauth/${api.name}/policy'
  dependsOn: [
    apimRouter
    apimRouterOperation
  ]
  properties:{
    format: 'xml'
    value: '<policies><inbound><validate-jwt header-name="Authorization" require-scheme="Bearer"><openid-config url="https://login.microsoftonline.com/${environment().authentication.tenant}/v2.0/.well-known/openid-configuration" /><required-claims><claim name="aud"><value>${api.aud}</value></claim><claim name="oid"><value>${api.oid}</value></claim></required-claims></validate-jwt><set-backend-service base-url="{{${api.backendName}}}" /><rewrite-uri template="${api.path}" copy-unmatched-params="false" /><set-header name="Authorization" exists-action="override"><value>Bearer {{kv-${api.vaultKey}}}</value></set-header><base /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}]
