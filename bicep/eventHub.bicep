// Azure Event Hub resource definition
param location string = 'East US'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: 'call-center-eh-namespace'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {}
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = {
  parent: eventHubNamespace
  name: 'call-records'
  properties: {
    messageRetentionInDays: 7
    partitionCount: 8
  }
}
