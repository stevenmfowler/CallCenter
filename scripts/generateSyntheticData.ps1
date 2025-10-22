# Generate Synthetic Test Data for Call Center Platform
# This script creates sample data for testing the platform

param(
    [Parameter(Mandatory = $false)]
    [int]$DaysBack = 30,

    [Parameter(Mandatory = $false)]
    [int]$RecordsPerDay = 100,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "data"
)

# Create output directory if it doesn't exist
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

Write-Host "Generating synthetic call data..." -ForegroundColor Green

# Sample data templates
$teamsTemplate = @{
    callId = ""
    startTime = ""
    endTime = ""
    participants = @()
    recording = $false
}

$avayaTemplate = @{
    callReference = ""
    timestamp = ""
    duration = 0
    extension = ""
}

$zoomTemplate = @{
    meetingId = ""
    topic = ""
    start_time = ""
    duration = 0
    participants_count = 0
}

$ringcentralTemplate = @{
    session = ""
    startTime = ""
    party = @{ displayName = ""; direction = "" }
    result = ""
}

# Helper functions
function Get-RandomDate {
    param([int]$DaysBack)
    $randomDays = Get-Random -Minimum 0 -Maximum $DaysBack
    return (Get-Date).AddDays(-$randomDays)
}

function Get-RandomDuration {
    return Get-Random -Minimum 300 -Maximum 3600  # 5 minutes to 1 hour
}

function Get-RandomParticipants {
    param([int]$count = $(Get-Random -Minimum 1 -Maximum 10))
    $names = @("John Doe", "Jane Smith", "Bob Johnson", "Alice Williams", "Charlie Brown", "Diana Ross", "Edward Norton", "Fiona Green", "George Lucas", "Helen Troy")
    $participants = @()
    for ($i = 0; $i -lt $count; $i++) {
        $participants += $names | Get-Random
    }
    return $participants
}

function Generate-TeamsData {
    param([int]$count, [array]$dates)

    $data = @()
    for ($i = 0; $i -lt $count; $i++) {
        $date = $dates | Get-Random
        $startTime = $date.AddHours((Get-Random -Minimum 8 -Maximum 18))
        $endTime = $startTime.AddSeconds((Get-Random -Minimum 600 -Maximum 3600))

        $record = $teamsTemplate.PSObject.Copy()
        $record.callId = "CALL_$i".PadLeft(7, '0')
        $record.startTime = $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $record.endTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $record.participants = Get-RandomParticipants
        $record.recording = (Get-Random -Maximum 2) -eq 1

        $data += $record
    }

    $data | ConvertTo-Json | Out-File "$OutputPath/teamsCallRecords_synthetic.json" -Encoding UTF8
    Write-Host "Generated $($data.Count) Teams call records"
}

function Generate-AvayaData {
    param([int]$count, [array]$dates)

    $data = @()
    for ($i = 0; $i -lt $count; $i++) {
        $date = $dates | Get-Random
        $timestamp = $date.AddHours((Get-Random -Minimum 8 -Maximum 18))

        $record = $avayaTemplate.PSObject.Copy()
        $record.callReference = "AVAYA_$i".PadLeft(7, '0')
        $record.timestamp = $timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        $record.duration = Get-Random -Minimum 60 -Maximum 3600
        $record.extension = "ext" + (Get-Random -Minimum 1000 -Maximum 9999)

        $data += $record
    }

    $data | ConvertTo-Csv -NoTypeInformation | Out-File "$OutputPath/avayaLogs_synthetic.csv" -Encoding UTF8
    Write-Host "Generated $($data.Count) Avaya log records"
}

function Generate-ZoomData {
    param([int]$count, [array]$dates)

    $topics = @("Team Standup", "Client Presentation", "Training Session", "Project Review", "All Hands Meeting", "One-on-One", "Interview", "Demo", "Workshop", "Planning Session")

    $data = @()
    for ($i = 0; $i -lt $count; $i++) {
        $date = $dates | Get-Random
        $startTime = $date.AddHours((Get-Random -Minimum 8 -Maximum 18))

        $record = $zoomTemplate.PSObject.Copy()
        $record.meetingId = "ZOOM_$i".PadLeft(7, '0')
        $record.topic = $topics | Get-Random
        $record.start_time = $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $record.duration = Get-Random -Minimum 15 -Maximum 120  # minutes
        $record.participants_count = Get-Random -Minimum 2 -Maximum 20

        $data += $record
    }

    $data | ConvertTo-Json | Out-File "$OutputPath/zoomMeetings_synthetic.json" -Encoding UTF8
    Write-Host "Generated $($data.Count) Zoom meeting records"
}

function Generate-RingcentralData {
    param([int]$count, [array]$dates)

    $directions = @("Inbound", "Outbound")
    $results = @("Answered", "Voicemail", "Missed", "Rejected", "Busy")
    $names = @("John Doe", "Jane Smith", "Bob Johnson", "Alice Williams", "Charlie Brown", "Diana Ross")

    $data = @()
    for ($i = 0; $i -lt $count; $i++) {
        $date = $dates | Get-Random
        $startTime = $date.AddHours((Get-Random -Minimum 8 -Maximum 18))

        $record = $ringcentralTemplate.PSObject.Copy()
        $record.session = "RC_$i".PadLeft(7, '0')
        $record.startTime = $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $record.party.displayName = $names | Get-Random
        $record.party.direction = $directions | Get-Random
        $record.result = $results | Get-Random

        $data += $record
    }

    $data | ConvertTo-Csv -NoTypeInformation | Out-File "$OutputPath/ringcentralCalls_synthetic.csv" -Encoding UTF8
    Write-Host "Generated $($data.Count) Ringcentral call records"
}

# Generate date range
$dates = @()
for ($i = 0; $i -lt $DaysBack; $i++) {
    $dates += (Get-Date).AddDays(-$i)
}

# Generate data for each source
Generate-TeamsData -count ($RecordsPerDay * $DaysBack) -dates $dates
Generate-AvayaData -count ($RecordsPerDay * $DaysBack) -dates $dates
Generate-ZoomData -count ($RecordsPerDay * $DaysBack) -dates $dates
Generate-RingcentralData -count ($RecordsPerDay * $DaysBack) -dates $dates

Write-Host "Synthetic data generation completed!" -ForegroundColor Green
