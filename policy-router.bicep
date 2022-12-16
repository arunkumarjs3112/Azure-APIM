param apimName string
param apiName string
param path string
param backendUrl string


resource apimNamedValueRouterUrl 'Microsoft.ApiManagement/service/namedValues@2020-12-01' = {
  name: '${apimName}/snaplogic-${path}-url'
  properties: {
    displayName: 'snaplogic-${path}-url'
    value: backendUrl
    secret: false
  }
}

resource apimRouter 'Microsoft.ApiManagement/service/apis@2020-12-01' = {
  name: '${apimName}/${path}'
  properties: {
    displayName: apiName
    path: '/${path}'
    apiRevision: '1'
    isCurrent: true
    subscriptionRequired: false
    protocols: [
        'https'
    ]
  }
}

resource apimRouterPolicy 'Microsoft.ApiManagement/service/apis/policies@2020-12-01' = {
  name: '${apimName}/${path}/policy'
  dependsOn: [
    apimRouter
  ]
  properties:{
    format: 'xml'
    value: '<policies><inbound><set-backend-service base-url="{{snaplogic-${path}-url}}" /> <base /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}

resource apimRouterOperation 'Microsoft.ApiManagement/service/apis/operations@2020-12-01' = {
  name: '${apimName}/${path}/post'
  dependsOn: [
    apimRouter
  ]
  properties:{
    displayName: 'POST'
    method: 'POST'
    urlTemplate: '/*'
  }
}

resource apimRouterOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = {
  name: '${apimName}/${path}/post/policy'
  dependsOn: [
    apimRouter
    apimRouterOperation
  ]
  properties:{
    format: 'xml'
    value: '<policies><inbound><set-variable name="esid" value="@(System.Linq.Enumerable.FirstOrDefault((System.Linq.Enumerable.Select(System.Linq.Enumerable.Where(System.Xml.Linq.XDocument.Parse(context.Request.Body.As&lt;string&gt;(preserveContent: true)).Descendants(), n =&gt; (n.Name.LocalName == &quot;customer_esid&quot; || n.Name.LocalName == &quot;client_duns_number&quot;) &amp;&amp; !string.IsNullOrEmpty(n.Value)), n =&gt; n.Value))))" /><choose><when condition="@(!string.IsNullOrEmpty((string)context.Variables[&quot;esid&quot;]))"><set-query-parameter name="esid" exists-action="override"><value>@((string)context.Variables["esid"])</value></set-query-parameter></when><otherwise><return-response><set-status code="400" reason="ESID or DUNS missing" /></return-response></otherwise></choose><base /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}
