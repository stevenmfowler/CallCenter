# Purge Old Records from Azure Table Storage
# This script removes call records older than 30 days

param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountKey,

    [Parameter(Mandatory = $false)]
    [int]$DaysOld = 30
)

# Connect to Azure Storage
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

# Get the table reference
$table = Get-AzStorageTable -Name "CallRecords" -Context $ctx

# Calculate cutoff date
$cutoffDate = (Get-Date).AddDays(-$DaysOld).ToString("yyyyMMdd")

# Get table service
$tableService = $ctx | New-AzStorageTableTableService

# Query for old records (assuming partition key contains date)
$entities = $tableService.QueryEntities("CallRecords", $null, $null, $null)

foreach ($entity in $entities) {
    # Parse PartitionKey as date for comparison
    try {
        $partitionKeyAsDate = [DateTime]::ParseExact($entity.PartitionKey, "yyyyMMdd", $null)
        if ($partitionKeyAsDate -lt (Get-Date).AddDays(-$DaysOld)) {
            $tableService.RemoveEntity("CallRecords", $entity)
            Write-Host "Deleted record: $($entity.RowKey)"
        }
    }
    catch {
        # If PartitionKey is not a date, skip it
        Write-Warning "Skipping entity with non-date partition key: $($entity.RowKey)"
    }
}

Write-Host "Cleanup completed successfully"
