# Blob Naming Convention for Call Center Platform

## Overview
This document defines the naming convention for blob storage files in the Call Center Platform.

## Naming Pattern
```
{source}/{year}/{month}/{day}/{call_id}_{timestamp}.{extension}
```

### Components
- **source**: Source system identifier (teams, avaya, zoom, ringcentral)
- **year**: 4-digit year (e.g., 2023)
- **month**: 2-digit month with leading zero (e.g., 01)
- **day**: 2-digit day with leading zero (e.g., 31)
- **call_id**: Unique call/meeting identifier from source system
- **timestamp**: ISO 8601 timestamp in format YYYYMMDD_HHMMSS
- **extension**: File extension (json, csv, etc.)

### Examples
- `teams/2023/10/01/CALL_001_20231001_093000.json`
- `avaya/2023/10/01/AVAYA_001_20231001_100000.csv`
- `zoom/2023/10/01/ZOOM_001_20231001_090000.json`
- `ringcentral/2023/10/01/RC_001_20231001_100000.csv`

## Rationale
- Hierarchical structure enables efficient partitioning and querying
- Date-based partitioning allows for retention policies and archival
- Call-specific identifiers ensure uniqueness
- Consistent format facilitates automation and indexing
