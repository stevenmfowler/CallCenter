#!/bin/bash
# Generate Synthetic Test Data for Call Center Platform using Azure CLI
# This script creates sample data for testing the platform

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
DAYS_BACK=30
RECORDS_PER_DAY=100
OUTPUT_PATH="data"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --days-back|-d)
            DAYS_BACK="$2"
            shift 2
            ;;
        --records-per-day|-r)
            RECORDS_PER_DAY="$2"
            shift 2
            ;;
        --output-path|-o)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Generate synthetic call data for testing the Call Center Platform"
            echo ""
            echo "Options:"
            echo "  -d, --days-back NUMBER       Number of days to generate data for (default: 30)"
            echo "  -r, --records-per-day COUNT  Number of records per day per source (default: 100)"
            echo "  -o, --output-path DIR        Output directory for generated files (default: data)"
            echo "  -h, --help                   Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --days-back 7 --records-per-day 50 --output-path ./test-data"
            exit 0
            ;;
        *)
            print_color $RED "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate parameters
if ! [[ "$DAYS_BACK" =~ ^[0-9]+$ ]] || [ "$DAYS_BACK" -le 0 ]; then
    print_color $RED "Error: days-back must be a positive integer"
    exit 1
fi

if ! [[ "$RECORDS_PER_DAY" =~ ^[0-9]+$ ]] || [ "$RECORDS_PER_DAY" -le 0 ]; then
    print_color $RED "Error: records-per-day must be a positive integer"
    exit 1
fi

print_color $GREEN "Generating synthetic call data..."
print_color $YELLOW "Parameters:"
echo "  Days back: $DAYS_BACK"
echo "  Records per day: $RECORDS_PER_DAY"
echo "  Output path: $OUTPUT_PATH"

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_PATH" ]; then
    mkdir -p "$OUTPUT_PATH"
    print_color $GREEN "Created output directory: $OUTPUT_PATH"
fi

# Function to generate random date within range
generate_random_date() {
    local base_date=$(date -d "now - $DAYS_BACK days" +%s)
    local random_offset=$((RANDOM % (DAYS_BACK * 24 * 60 * 60)))
    local random_date=$((base_date + random_offset))
    date -d "@$random_date" "+%Y-%m-%d %H:%M:%S"
}

# Function to generate random duration
generate_random_duration() {
    echo $((300 + RANDOM % 3300))  # 5 minutes to 1 hour
}

# Function to generate random participants
generate_random_participants() {
    local names=("John Doe" "Jane Smith" "Bob Johnson" "Alice Williams" "Charlie Brown" "Diana Ross" "Edward Norton" "Fiona Green" "George Lucas" "Helen Troy")
    local count=$((1 + RANDOM % 9))
    local result=""

    for ((i=0; i<count; i++)); do
        if [ $i -gt 0 ]; then
            result="$result, \"${names[RANDOM % ${#names[@]}]}\", \"${names[RANDOM % ${#names[@]}]}\", \"${names[RANDOM % ${#names[@]}]}\"@domain.com\""
        else
            result="\"${names[RANDOM % ${#names[@]}]}\", \"${names[RANDOM % ${#names[@]}]}\", \"${names[RANDOM % ${#names[@]}]}\"@domain.com\""
        fi
    done

    echo "[$result]"
}

# Function to generate random boolean
generate_random_bool() {
    if [ $((RANDOM % 2)) -eq 0 ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to generate random ID
generate_random_id() {
    echo "ID_$(printf "%09d" $RANDOM)"
}

# Function to generate random topic
generate_random_topic() {
    local topics=("Team Standup" "Client Presentation" "Training Session" "Project Review" "All Hands Meeting" "One-on-One" "Interview" "Demo" "Workshop" "Planning Session")
    echo "${topics[RANDOM % ${#topics[@]}]}"
}

# Function to generate random meeting duration
generate_random_meeting_duration() {
    echo $((15 + RANDOM % 106))  # 15 to 120 minutes
}

# Function to generate random participants count
generate_random_participants_count() {
    echo $((2 + RANDOM % 19))  # 2 to 20 participants
}

# Function to generate random department
generate_random_department() {
    local departments=("Emergency" "Surgery" "Cardiology" "Front Desk" "Concierge" "Dining" "Transportation" "Pharmacy" "Admissions" "Executive")
    echo "${departments[RANDOM % ${#departments[@]}]}"
}

# Function to generate random direction
generate_random_direction() {
    if [ $((RANDOM % 2)) -eq 0 ]; then
        echo "Inbound"
    else
        echo "Outbound"
    fi
}

# Function to generate random result
generate_random_result() {
    local results=("Answered" "Voicemail" "Missed" "Rejected" "Busy")
    echo "${results[RANDOM % ${#results[@]}]}"
}

# Function to generate Teams data
generate_teams_data() {
    local total_records=$(($DAYS_BACK * RECORDS_PER_DAY / 4))  # Divide by 4 sources
    local filename="$OUTPUT_PATH/teamsCallRecords_synthetic.json"

    print_color $YELLOW "Generating $total_records Teams call records..."

    cat > "$filename" << 'EOF'
[
EOF

    for ((i=0; i<total_records; i++)); do
        local random_date
        if [ "$(uname)" = "Darwin" ]; then
            # macOS date command is different
            random_date=$(date -v -$(($DAYS_BACK * $RANDOM / 32767))d "+%Y-%m-%dT%H:%M:%S")
        else
            random_date=$(date -d "$(generate_random_date)" "+%Y-%m-%dT%H:%M:%S")
        fi

        local end_time
        if [ "$(uname)" = "Darwin" ]; then
            end_time=$(date -v +$(($(generate_random_duration)/60))M -j -f "%Y-%m-%dT%H:%M:%S" "$random_date" "+%Y-%m-%dT%H:%M:%SZ")
        else
            end_time=$(date -d "$random_date $(($(generate_random_duration)/60)) minutes" "+%Y-%m-%dT%H:%M:%SZ")
        fi

        cat >> "$filename" << EOF
  {
    "callId": "$(generate_random_id)",
    "startTime": "${random_date}Z",
    "endTime": "${end_time}",
    "participants": $(generate_random_participants),
    "recording": $(generate_random_bool)
  }
EOF

        if [ $i -lt $((total_records - 1)) ]; then
            echo "," >> "$filename"
        fi
    done

    cat >> "$filename" << 'EOF'

]
EOF

    print_color $GREEN "Generated $total_records Teams call records in $filename"
}

# Function to generate Avaya data
generate_avaya_data() {
    local total_records=$(($DAYS_BACK * RECORDS_PER_DAY / 4))
    local filename="$OUTPUT_PATH/avayaLogs_synthetic.csv"

    print_color $YELLOW "Generating $total_records Avaya log records..."

    cat > "$filename" << 'EOF'
callReference,timestamp,duration,extension
EOF

    for ((i=0; i<total_records; i++)); do
        local random_date=""
        if [ "$(uname)" = "Darwin" ]; then
            random_date=$(date -v -$(($DAYS_BACK * $RANDOM / 32767))d "+%Y-%m-%d %H:%M:%S")
        else
            random_date=$(date -d "$(generate_random_date)" "+%Y-%m-%d %H:%M:%S")
        fi

        cat >> "$filename" << EOF
$(generate_random_id),${random_date},$(generate_random_duration),ext$((1000 + RANDOM % 9000))
EOF
    done

    print_color $GREEN "Generated $total_records Avaya log records in $filename"
}

# Function to generate Zoom data
generate_zoom_data() {
    local total_records=$(($DAYS_BACK * RECORDS_PER_DAY / 4))
    local filename="$OUTPUT_PATH/zoomMeetings_synthetic.json"

    print_color $YELLOW "Generating $total_records Zoom meeting records..."

    cat > "$filename" << 'EOF'
[
EOF

    for ((i=0; i<total_records; i++)); do
        local random_date=""
        if [ "$(uname)" = "Darwin" ]; then
            random_date=$(date -v -$(($DAYS_BACK * $RANDOM / 32767))d "+%Y-%m-%dT%H:%M:%S")
        else
            random_date=$(date -d "$(generate_random_date)" "+%Y-%m-%dT%H:%M:%S")
        fi

        cat >> "$filename" << EOF
  {
    "meetingId": "$(generate_random_id)",
    "topic": "$(generate_random_topic)",
    "start_time": "${random_date}Z",
    "duration": $(generate_random_meeting_duration),
    "participants_count": $(generate_random_participants_count)
  }
EOF

        if [ $i -lt $((total_records - 1)) ]; then
            echo "," >> "$filename"
        fi
    done

    cat >> "$filename" << 'EOF'

]
EOF

    print_color $GREEN "Generated $total_records Zoom meeting records in $filename"
}

# Function to generate Ringcentral data
generate_ringcentral_data() {
    local total_records=$(($DAYS_BACK * RECORDS_PER_DAY / 4))
    local filename="$OUTPUT_PATH/ringcentralCalls_synthetic.csv"

    print_color $YELLOW "Generating $total_records Ringcentral call records..."

    cat > "$filename" << 'EOF'
session,startTime,direction,displayName,result
EOF

    for ((i=0; i<total_records; i++)); do
        local random_date=""
        if [ "$(uname)" = "Darwin" ]; then
            random_date=$(date -v -$(($DAYS_BACK * $RANDOM / 32767))d "+%Y-%m-%dT%H:%M:%S")
        else
            random_date=$(date -d "$(generate_random_date)" "+%Y-%m-%dT%H:%M:%S")
        fi

        cat >> "$filename" << EOF
$(generate_random_id),${random_date}Z,\"$(generate_random_direction)\",\"System User\",\"$(generate_random_result)\"
EOF
    done

    print_color $GREEN "Generated $total_records Ringcentral call records in $filename"
}

# Generate data for all sources
generate_teams_data
generate_avaya_data
generate_zoom_data
generate_ringcentral_data

print_color $GREEN "Synthetic data generation completed successfully!"
print_color $YELLOW "Files generated:"
echo "  - $OUTPUT_PATH/teamsCallRecords_synthetic.json"
echo "  - $OUTPUT_PATH/avayaLogs_synthetic.csv"
echo "  - $OUTPUT_PATH/zoomMeetings_synthetic.json"
echo "  - $OUTPUT_PATH/ringcentralCalls_synthetic.csv"

total_files=$((4))
total_records=$((DAYS_BACK * RECORDS_PER_DAY))
print_color $YELLOW "Total: $total_records records across $total_files data sources"
