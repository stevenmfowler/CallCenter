#!/bin/bash
# Script to query a transaction (call) through the Call Center Platform pipeline
# Checks from ingestion to final disposition after records retention

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Default configuration
RESOURCE_GROUP="call-center-rg"
APP_INSIGHTS_NAME="call-center-appinsights"
STORAGE_ACCOUNT_NAME="callcenterstorage"
FUNCTION_APP_NAME="call-center-functions"
LOG_ANALYTICS_WORKSPACE="call-center-logs"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --call-id|-c)
            CALL_ID="$2"
            shift 2
            ;;
        --resource-group|-r)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        --app-insights|-a)
            APP_INSIGHTS_NAME="$2"
            shift 2
            ;;
        --storage-account|-s)
            STORAGE_ACCOUNT_NAME="$2"
            shift 2
            ;;
        --function-app|-f)
            FUNCTION_APP_NAME="$2"
            shift 2
            ;;
        --log-workspace|-l)
            LOG_ANALYTICS_WORKSPACE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --call-id CALL_ID [options]"
            echo "Query transaction processing through the Call Center Platform"
            echo ""
            echo "Options:"
            echo "  -c, --call-id CALL_ID         Call/Transaction ID to query (required)"
            echo "  -r, --resource-group RG       Azure Resource Group name (default: call-center-rg)"
            echo "  -a, --app-insights NAME       Application Insights resource name (default: call-center-appinsights)"
            echo "  -s, --storage-account NAME    Storage account name (default: callcenterstorage)"
            echo "  -f, --function-app NAME       Function App name (default: call-center-functions)"
            echo "  -l, --log-workspace NAME      Log Analytics workspace name (default: call-center-logs)"
            echo "  -h, --help                    Show this help message"
            echo ""
            echo "Requires Azure CLI to be logged in: az login"
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
if [ -z "$CALL_ID" ]; then
    print_color $RED "Error: Call ID is required"
    echo "Use --help for usage information"
    exit 1
fi

# Check if Azure CLI is installed and logged in
if ! command_exists az; then
    print_color $RED "Error: Azure CLI is not installed or not in PATH"
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    print_color $RED "Error: Not logged in to Azure CLI. Run 'az login' first"
    exit 1
fi

print_color $BLUE "=== Call Center Platform Transaction Query ==="
print_color $YELLOW "Call ID: $CALL_ID"
print_color $YELLOW "Resource Group: $RESOURCE_GROUP"
echo ""
print_color $BLUE "Checking transaction processing stages..."
echo ""

# Function to query Application Insights for traces
query_traces() {
    local timespan="$1"
    local query="traces | where message contains '$CALL_ID' | project timestamp, operation_Name, message | sort by timestamp asc"

    if [ -n "$timespan" ]; then
        query="$query | where timestamp >= ago(${timespan})"
    fi

    az monitor app-insights query \
        --resource "$APP_INSIGHTS_NAME" \
        --app "$APP_INSIGHTS_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --analytics-query "$query" \
        --output table \
        2>/dev/null || echo "Failed to query App Insights (check resource name and permissions)"
}

# Function to check if transaction exists in table storage
check_table_storage() {
    print_color $YELLOW "Checking Table Storage (CallRecords table)..."

    # Query for the call record
    az storage entity query \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --table-name "CallRecords" \
        --filter "CallId eq '$CALL_ID'" \
        --output json \
        --auth-mode key \
        2>/dev/null | jq -r '.[0].CallId' | grep -q "$CALL_ID"

    if [ $? -eq 0 ]; then
        print_color $GREEN "✓ Transaction found in Table Storage"
        # Get the record details
        RECORD=$(az storage entity query \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --table-name "CallRecords" \
            --filter "CallId eq '$CALL_ID'" \
            --output json \
            2>/dev/null | jq '.[0]')
        print_color $BLUE "  Details:"
        echo "$RECORD" | jq -r '. | "  Source: \(.PartitionKey)", "  Start Time: \(.StartTime)", "  Duration: \(.Duration)", "  Participants: \(.Participants)"' 2>/dev/null
    else
        print_color $RED "✗ Transaction not found in Table Storage"
    fi
    echo ""
}

# 1. Check ingestion (Transform function logs)
print_color $BLUE "1. Ingestion Stage"
print_color $YELLOW "Checking for ingestion logs (TransformUCLogs function)..."

INGEST_LOGS=$(query_traces "30d" | grep -i "$CALL_ID" | head -5)
if [ -n "$INGEST_LOGS" ]; then
    print_color $GREEN "✓ Ingestion detected"
    print_color $BLUE "  Recent ingestion logs:"
    echo "$INGEST_LOGS"
else
    print_color $RED "✗ No ingestion logs found in last 30 days"
    print_color $YELLOW "  (May have occurred before retention period)"
fi
echo ""

# 2. Check transformation (same logs)
print_color $BLUE "2. Transformation Stage"
print_color $YELLOW "Checking for transformation completion..."

# Check if Transform function logged success for this call
TRANSFORM_SUCCESS=$(query_traces "30d" | grep -E "(TransformUCLogs.*processed.*message|Data transformed successfully)" | grep "$CALL_ID" | head -1)
if [ -n "$TRANSFORM_SUCCESS" ]; then
    print_color $GREEN "✓ Transformation completed"
else
    if [ -n "$INGEST_LOGS" ]; then
        print_color $YELLOW "? Transformation in progress or failed"
    else
        print_color $RED "✗ No transformation evidence"
    fi
fi
echo ""

# 3. Check routing to storage
print_color $BLUE "3. Routing to Storage Stage"
print_color $YELLOW "Checking for routing function logs (RouteToStorage)..."

ROUTE_LOGS=$(query_traces "30d" | grep -i "RouteToStorage" | grep "$CALL_ID" | head -5)
if [ -n "$ROUTE_LOGS" ]; then
    print_color $GREEN "✓ Routing completed"
else
    print_color $RED "✗ No routing logs found"
fi
echo ""

# 4. Check final disposition
print_color $BLUE "4. Final Disposition"
check_table_storage

# 5. Check for disposition after retention
print_color $BLUE "5. Post-Retention Status"
print_color $YELLOW "Checking if transaction is beyond retention period..."

# Get retention policy (assume 30 days default, check if we can get from logs)
# This is simplified - in production you might store retention config
RETENTION_DAYS=30

if [ -n "$RECORD" ]; then
    START_TIME=$(echo "$RECORD" | jq -r '.StartTime' 2>/dev/null)
    if [ -n "$START_TIME" ] && [ "$START_TIME" != "null" ]; then
        # Calculate age in days (simplified)
        if command_exists date; then
            NOW=$(date +%s)
            START=$(date -d "$START_TIME" +%s 2>/dev/null) || START=""
            if [ -n "$START" ]; then
                AGE_DAYS=$(( (NOW - START) / 86400 ))
                if [ $AGE_DAYS -gt $((RETENTION_DAYS + 1)) ]; then
                    print_color $YELLOW "⚠ Record is $AGE_DAYS days old (retention: $RETENTION_DAYS days)"
                    print_color $YELLOW "  This record should have been purged by retention policy"
                else
                    print_color $GREEN "✓ Record within retention period"
                fi
            fi
        fi
    fi
fi

echo ""
print_color $BLUE "=== Query Complete ==="
print_color $YELLOW "Transaction ID: $CALL_ID"

# Summary
if [ -n "$RECORD" ]; then
    print_color $GREEN "SUMMARY: Transaction successfully processed to final disposition"
elif [ -n "$INGEST_LOGS" ]; then
    print_color $YELLOW "SUMMARY: Transaction ingested but may have failed processing or been retained"
else
    print_color $RED "SUMMARY: No evidence of this transaction in the system"
fi

exit 0
