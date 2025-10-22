# Call Center Platform

A serverless data processing platform for ingesting, transforming, and storing call records from multiple UCaaS and PBX systems.

## Architecture Overview

The platform implements a unified data pipeline that:
- Ingests call data from Microsoft Teams, Avaya, Zoom, and Ringcentral
- Transforms data into a standardized schema
- Stores processed data in Azure Table Storage and Blob Storage
- Provides monitoring and observability through Azure Monitor

## Components

### Infrastructure (IaC)
- **Azure Bicep**: Infrastructure as Code for all Azure resources
- **Storage Account**: Structured data storage and blob containers
- **Event Hubs**: Message streaming between components
- **Key Vault**: Secure secrets management
- **Function Apps**: Serverless compute for data processing

### Data Processing Pipeline
1. **Ingestion**: HTTP triggers for Teams, REST APIs for other sources
2. **Transformation**: Event-driven functions normalize data schemas
3. **Storage**: Dual write to Table Storage (metadata) and Blob Storage (raw data)

### Observability & Compliance
- **Application Insights**: Performance monitoring and diagnostics
- **Azure Monitor**: Infrastructure and security monitoring
- **Log Analytics**: Centralized log aggregation
- **Compliance**: HIPAA, PCI-DSS, and GDPR compliance controls

## Quick Start

### Prerequisites
- Azure CLI (`az`) installed and authenticated
- Azure Bicep CLI installed
- PowerShell 7+ (for deployment scripts)

### Deployment

#### Option 1: PowerShell Script (Windows/macOS/Linux)
1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd CallCenterPlatform
   ```

2. **Deploy infrastructure**
   ```powershell
   .\scripts\deploy.ps1 -ResourceGroupName "callcenter-rg" -Location "East US" -Environment "dev"
   ```

#### Option 2: Bash Script (Linux/macOS)
1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd CallCenterPlatform
   ```

2. **Deploy infrastructure**
   ```bash
   ./scripts/deploy.sh --resource-group "callcenter-rg" --location "East US" --environment "dev"
   ```

   Available options:
   ```bash
   ./scripts/deploy.sh --help
   ```

3. **Configure source integrations**
   - Set up webhooks for Microsoft Teams Graph API
   - Configure REST endpoints for Avaya/Zoom/Ringcentral
   - Update connection strings in Key Vault

4. **Generate test data**
   ```powershell
   .\scripts\generateSyntheticData.ps1 -DaysBack 7 -RecordsPerDay 50
   ```

## Development

### Project Structure
```
CallCenterPlatform/
├── bicep/               # Infrastructure as Code
├── functions/           # Azure Functions code
├── config/              # Application configuration
├── data/                # Sample and test data
├── tests/               # Unit and integration tests
├── docs/                # Documentation
└── scripts/             # Deployment and utility scripts
```

### Testing
#### PowerShell Tests (Windows/macOS/Linux)
```powershell
# Run unit tests
dotnet test tests/unit/

# Run integration tests
dotnet test tests/integration/

# Generate synthetic test data
.\scripts\generateSyntheticData.ps1 -DaysBack 7 -RecordsPerDay 50

# Clean up old records
.\scripts\purgeOldRecords.ps1 -StorageAccountName "mystorage" -StorageAccountKey "xxx...xxx"
```

#### Bash Tests (Linux/macOS)
```bash
# Run unit tests
dotnet test tests/unit/

# Run integration tests
dotnet test tests/integration/

# Generate synthetic test data
./scripts/generateSyntheticData.sh --days-back 7 --records-per-day 50

# Clean up old records
./scripts/purgeOldRecords.sh --storage-account "mystorage" --account-key "xxx...xxx"
```

### Monitoring

Access monitoring data through:
- **Azure Portal**: Function Apps > Application Insights
- **Log Analytics**: Workspace queries for operational data
- **Azure Monitor**: Dashboards and alert rules

## Target Clients

### Piedmont Healthcare
- **Industry**: Healthcare / PHI Processing
- **Compliance**: HIPAA BAA compliant platform
- **Use Cases**: Telemedicine consultations, patient follow-ups, care coordination calls
- **Data Sensitivity**: Protected Health Information (PHI), patient data, medical records

### Marriott Hotels & Resorts
- **Industry**: Hospitality / PCI-DSS transactions
- **Compliance**: PCI DSS Level 1 certified platform
- **Use Cases**: Guest reservations, concierge services, room service, event bookings
- **Data Sensitivity**: Payment information, guest PII, reservation details

## Supported Data Sources

### Microsoft Teams (Piedmont Healthcare)
- **Use Case**: Virtual patient consultations and care coordination
- **Input**: JSON via Graph API webhooks
- **Fields**: callId, startTime, endTime, participants, recording, metadata (department, patientId)
- **PII Handling**: Patient identifiers masked, HIPAA-compliant logging

### Avaya PBX (Both Clients)
- **Piedmont Use Case**: Hospital phone system for admissions, emergency calls
- **Marriott Use Case**: Hotel PBX for reservations, concierge, room service
- **Input**: CSV logs via REST API
- **Fields**: callReference, timestamp, duration, extension, callerId, department
- **Compliance**: PII masking, call detail recording for audit trails

### Zoom Meetings (Piedmont Healthcare)
- **Use Case**: Multi-disciplinary tumor board reviews, remote consultations
- **Input**: JSON via webhooks
- **Fields**: meetingId, topic, start_time, duration, participants_count, metadata
- **Compliance**: HIPAA-protected meeting data with confidentiality markings

### Ringcentral (Both Clients)
- **Piedmont Use Case**: Pharmacy calls, admissions coordination, physician referrals
- **Marriott Use Case**: Restaurant reservations, transportation services
- **Input**: CSV via REST API
- **Fields**: session, startTime, direction, displayName, result, department
- **Compliance**: PCI DSS compliant for payment-related calls

## Data Schema

All source data is normalized to a unified schema:

```json
{
  "id": "unique-identifier",
  "source": "Teams|Avaya|Zoom|Ringcentral",
  "callId": "source-specific-identifier",
  "startTime": "ISO-8601-datetime",
  "endTime": "ISO-8601-datetime",
  "duration": "integer-minutes",
  "participants": ["participant-names"],
  "recording": "boolean",
  "partitionKey": "yyyyMMdd",
  "rowKey": "unique-guid"
}
```

## Security & Compliance

- **Encryption**: Data encrypted at rest and in transit
- **Access Control**: RBAC with least privilege
- **Auditing**: Comprehensive audit logging
- **Compliance**: HIPAA BAA, PCI DSS Level 1, GDPR

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

## Support

For issues or questions:
- Create GitHub issues for bugs/features
- Review documentation in `docs/` directory
- Check logs in Azure Application Insights

## License

MIT License
