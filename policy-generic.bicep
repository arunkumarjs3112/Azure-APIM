param apimName string
param apiName string
param apiDisplayName string
param path string
param backendName string
param backendUrl string

resource apimApiGenericNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-04-01-preview' = {
  name: '${apimName}/${backendName}'
  properties: {
    displayName: backendName
    value: backendUrl
    secret: false
  }
}

resource apimApiGeneric 'Microsoft.ApiManagement/service/apis@2022-04-01-preview' = {
  name: '${apimName}/${apiName}'
  properties: {
    displayName: apiDisplayName
    path: path
    apiRevision: '1'
    isCurrent: true
    subscriptionRequired: false
    protocols: [
        'https'
    ]
  }
}

resource apimGenericPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-04-01-preview' = {
  name: '${apimName}/${apiName}/policy'
  dependsOn: [
    apimApiGeneric
  ]
  properties:{
    format: 'xml'
    value: '<policies><inbound><set-backend-service base-url="{{${backendName}}}" /><base /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}

resource apimGenericPostOperation 'Microsoft.ApiManagement/service/apis/operations@2022-04-01-preview' = {
  name: '${apimName}/${apiName}/post'
  dependsOn: [
    apimApiGeneric
  ]
  properties:{
    displayName: 'POST'
    method: 'POST'
    urlTemplate: '/*'
  }
}

resource apimGenericPostOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-04-01-preview' = {
  name: '${apimName}/${apiName}/post/policy'
  dependsOn: [
    apimApiGeneric
    apimGenericPostOperation
  ]
  properties:{
    format: 'xml'
    value: '<policies><inbound><base /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}

resource apimGenericPutOperation 'Microsoft.ApiManagement/service/apis/operations@2022-04-01-preview' = {
  name: '${apimName}/${apiName}/put'
  dependsOn: [
    apimApiGeneric
  ]
  properties:{
    displayName: 'PUT'
    method: 'PUT'
    urlTemplate: '/*'
  }
}

resource apimGenericPutOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-04-01-preview' = {
  name: '${apimName}/${apiName}/put/policy'
  dependsOn: [
    apimApiGeneric
    apimGenericPatchOperation
  ]
  properties:{
    format: 'xml'
    value: '<policies><inbound><base /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}

resource apimGenericPatchOperation 'Microsoft.ApiManagement/service/apis/operations@2022-04-01-preview' = {
  name: '${apimName}/${apiName}/patch'
  dependsOn: [
    apimApiGeneric
  ]
  properties:{
    displayName: 'PATCH'
    method: 'PATCH'
    urlTemplate: '/*'
  }
}

resource apimGenericPatchOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-04-01-preview' = {
  name: '${apimName}/${apiName}/patch/policy'
  dependsOn: [
    apimApiGeneric
    apimGenericPatchOperation
  ]
  properties:{
    format: 'xml'
    value: '<policies><inbound><base /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}
