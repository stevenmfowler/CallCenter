// Azure Function App resource definition
param location string = 'East US'
param runtime string = 'dotnet'
param appServicePlanId string

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'call-center-functions'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime
        }
      ]
    }
  }
}
