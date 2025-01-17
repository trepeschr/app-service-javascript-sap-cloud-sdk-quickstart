targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param apiServiceName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param keyVaultName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''

// Name of the SKU; default is F1 (Free)
@description('Name of the SKU of the App Service Plan')
param skuName string = 'F1'

@description('Id of the user or app to assign application roles')
param principalId string = ''

// App specific parameters - provide the values via the main.parameters.json referencing e.g. environment parameters
@description('SAP OData service URL')
param oDataUrl string = 'https://sandbox.api.sap.com/s4hanacloud'

@description('SAP OData user name')
param oDataUsername string = ''

@description('SAP OData user password')
@secure()
param oDataUserpwd string = ''

@description('API Key')
@secure()
param _APIKey string = ''

@description('API Key Header Name')
param ApiKeyHeaderName string = 'APIKey'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// The application backend
module api './app/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesAppService}api-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    appSettings: {
      ODATA_URL: oDataUrl
      ODATA_USERNAME: oDataUsername
      ODATA_USERPWD: '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.endpoint}secrets/${abbrs.keyVaultVaults}secret-odata-password)'
      APIKEY: '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.endpoint}secrets/${abbrs.keyVaultVaults}secret-apikey)'
      APIKEY_HEADERNAME: ApiKeyHeaderName
    }
    use32BitWorkerProcess: skuName == 'F1' || skuName == 'FREE' || skuName == 'SHARED' ? true : false
    alwaysOn: skuName == 'F1' || skuName == 'FREE' || skuName == 'SHARED' ? false : true
  }
}

// Give the API access to KeyVault
module apiKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'api-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: api.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: skuName
    }
  }
}

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

// Store Odata Password in KeyVault
module oDataPassword './core/security/keyvault-secret.bicep' = {
  name: 'odatapassword'
  scope: rg
  params: {
    name: '${abbrs.keyVaultVaults}secret-odata-password'
    keyVaultName: keyVault.outputs.name
    tags: tags
    secretValue: oDataUserpwd
  }
}

// Store API key in KeyVault
module ApiKey './core/security/keyvault-secret.bicep' = {
  name: 'apikey'
  scope: rg
  params: {
    name: '${abbrs.keyVaultVaults}secret-apikey'
    keyVaultName: keyVault.outputs.name
    tags: tags
    secretValue: _APIKey
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SAP_CLOUD_SDK_API_URL string = api.outputs.SERVICE_API_URI
output SAP_CLOUD_SDK_API_APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
