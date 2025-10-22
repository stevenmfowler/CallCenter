# Call Center Platform Deployment Script
# This script deploys the infrastructure and application components

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $true)]
    [string]$Environment
)

# Set error handling
$ErrorActionPreference = "Stop"

Write-Host "Starting deployment of Call Center Platform..." -ForegroundColor Green

# Validate prerequisites
Write-Host "Validating prerequisites..." -ForegroundColor Yellow
az account show --output none
if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI login required. Please run 'az login' first."
}

# Check Bicep CLI
bicep --version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Azure Bicep CLI not installed. Please install from https://github.com/Azure/bicep"
}

# Create resource group if it doesn't exist
Write-Host "Ensuring resource group exists..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none

# Deploy infrastructure
Write-Host "Deploying infrastructure..." -ForegroundColor Yellow
$deploymentName = "callcenter-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Deploy Bicep modules
$modules = @("storage", "keyVault", "eventHub", "functionApp")
foreach ($module in $modules) {
    $bicepFile = "bicep/$module.bicep"
    $params = @{
        "location" = $Location
    }

    if ($module -eq "functionApp") {
        # Get app service plan ID from previous deployment
        $appServicePlanId = az deployment group show `
            --resource-group $ResourceGroupName `
            --name $deploymentName `
            --query "properties.outputs.appServicePlanId.value" `
            --output tsv
        $params["appServicePlanId"] = $appServicePlanId
    }

    if ($module -eq "keyVault") {
        $objectId = az ad signed-in-user show --query id --output tsv
        $params["objectId"] = $objectId
    }

    # Deploy Bicep template
    az deployment group create `
        --resource-group $ResourceGroupName `
        --name "$deploymentName-$module" `
        --template-file $bicepFile `
        --parameters ($params | ConvertTo-Json) `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to deploy $module"
    }

    Write-Host "Successfully deployed $module" -ForegroundColor Green
}

# Deploy Azure Functions code
Write-Host "Deploying Azure Functions..." -ForegroundColor Yellow
$functionAppName = "call-center-functions-$Environment"

az functionapp deployment source config `
    --name $functionAppName `
    --resource-group $ResourceGroupName `
    --repo-url $env:GIT_REPO_URL `
    --branch main `
    --manual-integration

if ($LASTEXITCODE -ne 0) {
    throw "Failed to configure function app deployment source"
}

# Configure application settings
Write-Host "Configuring application settings..." -ForegroundColor Yellow
$appSettings = Get-Content "config/appsettings.json" | ConvertFrom-Json

# Get connection strings and keys
$eventHubConnectionString = az eventhubs namespace authorization-rule keys list `
    --resource-group $ResourceGroupName `
    --namespace-name "call-center-eh-namespace" `
    --name "RootManageSharedAccessKey" `
    --query primaryConnectionString `
    --output tsv

$storageConnectionString = az storage account show-connection-string `
    --resource-group $ResourceGroupName `
    --name (az storage account list --resource-group $ResourceGroupName --query "[0].name" --output tsv) `
    --query connectionString `
    --output tsv

$keyVaultName = az keyvault list --resource-group $ResourceGroupName --query "[0].name" --output tsv

$appSettings.Values.EventHubConnectionString = $eventHubConnectionString
$appSettings.Values.AzureWebJobsStorage = $storageConnectionString
$appSettings.Values.KeyVaultName = $keyVaultName

# Update function app settings
az functionapp config appsettings set `
    --name $functionAppName `
    --resource-group $ResourceGroupName `
    --setting "AzureWebJobsStorage=$storageConnectionString" "EventHubConnectionString=$eventHubConnectionString" "KeyVaultName=$keyVaultName"

# Deploy diagnostics settings
Write-Host "Configuring diagnostics..." -ForegroundColor Yellow
$logAnalyticsWorkspace = az monitor diagnostic-settings create `
    --name "callcenter-diagnostics" `
    --resource "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$functionAppName" `
    --logs '[{"category": "FunctionAppLogs", "enabled": true}]' `
    --metrics '[{"category": "AllMetrics", "enabled": true}]' `
    --workspace "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/callcenter-workspace" `
    --output none

# Run smoke tests
Write-Host "Running smoke tests..." -ForegroundColor Yellow
# TODO: Implement smoke tests

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure source system integrations" -ForegroundColor White
Write-Host "2. Set up monitoring dashboards" -ForegroundColor White
Write-Host "3. Configure alert rules" -ForegroundColor White
Write-Host "4. Test data ingestion from each source" -ForegroundColor White
