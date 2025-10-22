#!/bin/bash
# Purge Old Records from Azure Table Storage using Azure CLI
# This script removes call records older using az storage entity commands

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
    command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Configuration variables
STORAGE_ACCOUNT_NAME=""
STORAGE_ACCOUNT_KEY=""
DAYS_OLD=30

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --storage-account|-s)
            STORAGE_ACCOUNT_NAME="$2"
            shift 2
            ;;
        --account-key|-k)
            STORAGE_ACCOUNT_KEY="$2"
            shift 2
            ;;
        --days-old|-d)
            DAYS_OLD="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Purge old records from Azure Table Storage"
            echo ""
            echo "Options:"
            echo "  -s, --storage-account NAME  Storage account name (required)"
            echo "  -k, --account-key KEY       Storage account key (required)"
            echo "  -d, --days-old DAYS         Delete records older than this many days (default: 30)"
            echo "  -h, --help                  Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --storage-account mystorage --account-key 'xxx...xxx' --days-old 90"
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
if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
    print_color $RED "Error: Storage account name is required"
    echo "Use --help for usage information"
    exit 1
fi

if [ -z "$STORAGE_ACCOUNT_KEY" ]; then
    print_color $RED "Error: Storage account key is required"
    echo "Use --help for usage information"
    exit 1
fi

if ! [[ "$DAYS_OLD" =~ ^[0-9]+$ ]] || [ "$DAYS_OLD" -le 0 ]; then
    print_color $RED "Error: days-old must be a positive integer"
    exit 1
fi

print_color $GREEN "Starting Azure Table Storage cleanup..."
print_color $YELLOW "Parameters:"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  Days Old: $DAYS_OLD"

# Calculate cutoff date
CUTOFF_DATE=""
if [ "$(uname)" = "Darwin" ]; then
    CUTOFF_DATE=$(date -v -${DAYS_OLD}d "+%Y%m%d")
else
    CUTOFF_DATE=$(date -d "$DAYS_OLD days ago" "+%Y%m%d")
fi

print_color $YELLOW "Will delete records with partition keys before: $CUTOFF_DATE"

# List entities to be deleted
print_color $YELLOW "Querying entities to delete..."

# Use Azure CLI to query table entities
# Note: This is a simplified approach. For large datasets, you might need to use batch operations
ENTITIES_TO_DELETE=$(az storage entity query \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_ACCOUNT_KEY" \
    --table-name "CallRecords" \
    --filter "PartitionKey lt '$CUTOFF_DATE'" \
    --select "PartitionKey RowKey" \
    --output json \
    --query "[].{PartitionKey: PartitionKey, RowKey: RowKey}" 2>/dev/null || echo "[]")

# Count entities to be deleted
ENTITY_COUNT=$(echo "$ENTITIES_TO_DELETE" | jq length 2>/dev/null || echo "0")

if [ "$ENTITY_COUNT" = "0" ]; then
    print_color $GREEN "No records to delete. All records are within the retention period."
    exit 0
fi

print_color $YELLOW "Found $ENTITY_COUNT records to delete"

# Confirm deletion
read -p "Do you want to proceed with deleting these records? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_color $YELLOW "Operation cancelled by user"
    exit 0
fi

# Delete entities using batch operations
print_color $YELLOW "Deleting records..."

# For efficiency with large datasets, process in batches
DELETED_COUNT=0
ERRORS=0

echo "$ENTITIES_TO_DELETE" | jq -c '.[]' | while read -r entity; do
    PARTITION_KEY=$(echo "$entity" | jq -r '.PartitionKey')
    ROW_KEY=$(echo "$entity" | jq -r '.RowKey')

    if az storage entity delete \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --account-key "$STORAGE_ACCOUNT_KEY" \
        --table-name "CallRecords" \
        --partition-key "$PARTITION_KEY" \
        --row-key "$ROW_KEY" \
        --output none 2>/dev/null; then
        ((DELETED_COUNT++))
        if [ $((DELETED_COUNT % 10)) -eq 0 ]; then
            print_color $GREEN "Deleted $DELETED_COUNT records..."
        fi
    else
        ((ERRORS++))
        print_color $RED "Failed to delete record: $PARTITION_KEY, $ROW_KEY"
    fi
done

print_color $GREEN "Cleanup completed!"
print_color $YELLOW "Summary:"
echo "  Records deleted: $DELETED_COUNT"
echo "  Errors: $ERRORS"
echo "  Cutoff date: $CUTOFF_DATE"
echo "  Retention period: $DAYS_OLD days"

if [ $ERRORS -gt 0 ]; then
    print_color $YELLOW "Some records could not be deleted. Please check the error messages above."
    exit 1
fi

print_color $GREEN "All operations completed successfully"
