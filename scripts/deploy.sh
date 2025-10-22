#!/bin/bash
# Azure CLI Deployment Script for Call Center Platform
# This script deploys the infrastructure and application components using az CLI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Configuration variables
RESOURCE_GROUP_NAME=""
LOCATION="East US"
ENVIRONMENT="dev"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --resource-group|-g)
            RESOURCE_GROUP_NAME="$2"
            shift 2
            ;;
        --location|-l)
            LOCATION="$2"
            shift 2
            ;;
        --environment|-e)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -g, --resource-group NAME    Resource group name (required)"
            echo "  -l, --location LOCATION      Azure region (default: East US)"
            echo "  -e, --environment ENV        Environment name (default: dev)"
            echo "  -h, --help                   Show this help message"
            exit 0
            ;;
        *)
            print_color $RED "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP_NAME" ]; then
    print_color $RED "Error: Resource group name is required"
    echo "Use --help for usage information"
    exit 1
fi

print_color $GREEN "Starting deployment of Call Center Platform..."

# Validate prerequisites
print_color $YELLOW "Validating prerequisites..."

# Check if az CLI is installed and user is logged in
if ! command_exists az; then
    print_color $RED "Azure CLI (az) is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! az account show --output none 2>/dev/null; then
    print_color $RED "Azure CLI login required. Please run 'az login' first."
    exit 1
fi

# Check if bicep CLI is installed
if ! command_exists bicep; then
    print_color $RED "Azure Bicep CLI not installed. Please install from https://github.com/Azure/bicep"
    exit 1
fi

print_color $GREEN "Prerequisites validated successfully"

# Create resource group if it doesn't exist
print_color $YELLOW "Ensuring resource group exists..."
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" --output none 2>/dev/null && print_color $GREEN "Resource group created" || print_color $GREEN "Resource group already exists"

# Deploy infrastructure
print_color $YELLOW "Deploying infrastructure..."

DEPLOYMENT_NAME="callcenter-$(date +%Y%m%d%H%M%S)"
MODULES=("storage" "keyVault" "eventHub" "functionApp")

for module in "${MODULES[@]}"; do
    BICEP_FILE="bicep/${module}.bicep"
    PARAMS="{\"location\": {\"value\": \"$LOCATION\"}}"

    # Add specific parameters for certain modules
    case $module in
        "functionApp")
            # Get app service plan ID from previous deployment
            # Note: This approach assumes sequential deployment. In production, you might want to pre-create the app service plan
            ;;
        "keyVault")
            # Get current user's object ID for key vault access policy
            USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)
            # Given bicep template expects objectId parameter for access policy
            ;;
    esac

    print_color $YELLOW "Deploying $module..."

    # Note: For production, you'd want to move parameters to a proper params file
    PARAMETERS="--parameters location=$LOCATION"

    if [ "$module" = "keyVault" ] && [ -n "$USER_OBJECT_ID" ]; then
        PARAMETERS="$PARAMETERS objectId=$USER_OBJECT_ID"
    fi

    az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME-$module" \
        --template-file "$BICEP_FILE" \
        $PARAMETERS \
        --output none

    if [ $? -ne 0 ]; then
        print_color $RED "Failed to deploy $module"
        exit 1
    fi

    print_color $GREEN "Successfully deployed $module"
done

# Get deployed resource information
print_color $YELLOW "Retrieving deployment information..."

STORAGE_ACCOUNT_NAME=$(az storage account list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" --output tsv)
KEYVAULT_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" --output tsv)
EVENTHUB_NAMESPACE=$(az eventhubs namespace list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" --output tsv)

if [ -n "$STORAGE_ACCOUNT_NAME" ]; then
    STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query connectionString --output tsv)
fi

if [ -n "$EVENTHUB_NAMESPACE" ]; then
    EVENTHUB_CONNECTION_STRING=$(az eventhubs namespace authorization-rule keys list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --namespace-name "$EVENTHUB_NAMESPACE" \
        --name "RootManageSharedAccessKey" \
        --query primaryConnectionString \
        --output tsv 2>/dev/null || echo "")
fi

# Wait a bit for resources to be fully provisioned
print_color $YELLOW "Waiting for resources to be fully provisioned..."
sleep 10

# Deploy Azure Functions (Note: This assumes you have the code in a repository)
FUNCTION_APP_NAME="call-center-functions-$ENVIRONMENT"

# Check if function app exists
if az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    print_color $YELLOW "Deploying Azure Functions code..."
    print_color $YELLOW "Note: Function deployment requires a configured source repository"
    print_color $YELLOW "Please configure CI/CD pipeline or use 'az functionapp deployment source config'"
else
    print_color $YELLOW "Function app not found. Skipping function code deployment."
fi

# Configure application settings if we have the required information
if [ -n "$STORAGE_CONNECTION_STRING" ] && [ -n "$EVENTHUB_CONNECTION_STRING" ] && [ -n "$KEYVAULT_NAME" ]; then
    print_color $YELLOW "Configuring application settings..."

    az functionapp config appsettings set \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --setting "AzureWebJobsStorage=$STORAGE_CONNECTION_STRING" \
               "EventHubConnectionString=$EVENTHUB_CONNECTION_STRING" \
               "KeyVaultName=$KEYVAULT_NAME" \
        --output none 2>/dev/null || print_color $YELLOW "Could not update function app settings (function app may not exist yet)"
fi

# Store secrets in Key Vault if it exists
if [ -n "$KEYVAULT_NAME" ] && [ -n "$EVENTHUB_CONNECTION_STRING" ]; then
    print_color $YELLOW "Storing secrets in Key Vault..."
    az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "EventHubConnectionString" --value "$EVENTHUB_CONNECTION_STRING" --output none 2>/dev/null || print_color $YELLOW "Could not store EventHub secret"
fi

print_color $GREEN "Infrastructure deployment completed successfully!"

print_color $YELLOW "Next steps:"
echo "1. Configure source system integrations (Teams Graph API, Avaya, Zoom, Ringcentral)"
echo "2. Set up monitoring dashboards in Azure Monitor"
echo "3. Configure alert rules for proactive monitoring"
echo "4. Test data ingestion from each source system"
echo "5. Review the deployed resources in the Azure portal"

print_color $GREEN "Deployment summary:"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Location: $LOCATION"
echo "Environment: $ENVIRONMENT"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Key Vault: $KEYVAULT_NAME"
echo "Event Hub Namespace: $EVENTHUB_NAMESPACE"
echo "Function App: $FUNCTION_APP_NAME"

print_color $GREEN "Deployment completed successfully!"
