#!/usr/bin/env bash
#
# Copyright (c) 2024. All rights reserved.
#
# Name: script_zfs-autobackup.sh
# Version: 1.0.10
# Author: Mstaaravin
# Description: ZFS backup script with automated snapshot management and logging
#             This script performs ZFS backups using zfs-autobackup tool
#
# Usage: ./script_zfs-autobackup.sh [pool_name]
#
# Exit codes:
#   0 - Success
#   1 - Dependency check failed/Pool validation failed
#

# Ensure script fails on any error
set -e

# Enable debug mode for cron troubleshooting
# set -x

# Global configuration

# Remote destination - can be either:
# - SSH config hostname (in ~/.ssh/config, e.g., "zima01")
# - Direct IP address (e.g., "192.168.1.100")
# Requires SSH key authentication and ZFS permissions on remote host (normally using root)
REMOTE_HOST="zima01"
REMOTE_POOL_BASEPATH="WD181KFGX/BACKUPS"


# Basic logging configuration and date formats
LOG_DIR="/root/logs"
DATE=$(date +%Y%m%d_%H%M)                         # Used for filenames (YYYYMMDD)
TIMESTAMP="[$(date '+%Y-%m-%d %H:%M:%S')]"   # Used for log messages
START_TIME=$(date +%s)                       # Used for duration calculation

# Function to update timestamp
update_timestamp() {
    TIMESTAMP="[$(date '+%Y-%m-%d %H:%M:%S')]"
}

# Ensure PATH includes necessary directories
export PATH="/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# Source pools to backup if none specified
SOURCE_POOLS=(
    "zlhome01"
)


# For tracking statistics
declare -A BACKUP_STATS
declare -A DATASETS_INFO
declare -a CREATED_SNAPSHOTS

# For snapshot type classification and tracking
declare -A SNAPSHOT_TYPES     # Stores the type of each snapshot (monthly, weekly, daily)
declare -A SNAPSHOT_COUNTS    # Counts of snapshots by dataset and type
declare -A MONTHLY_DISTRIBUTION # Counters by month and type


# Logs messages to both syslog and stdout
# Uses global TIMESTAMP for consistency
log_message() {
    update_timestamp
    echo "${TIMESTAMP} $1" | logger -t zfs-backup
    echo "${TIMESTAMP} $1"
}

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    log_message "Error: This script must be run as root"
    exit 1
fi

# Verifies zfs-autobackup is installed and accessible
check_dependencies() {
    if ! command -v zfs-autobackup >/dev/null 2>&1; then
        log_message "Error: zfs-autobackup is not installed"
        return 1
    fi
    return 0
}

# Validate if ZFS pool exists and has required properties
validate_pool() {
    local pool=$1
    if ! zfs list "$pool" >/dev/null 2>&1; then
        log_message "Error: Pool $pool does not exist"
        return 1
    fi

    # Verify autobackup property is set
    if ! zfs get autobackup:${pool} ${pool} | grep -q "true"; then
        log_message "Error: autobackup:${pool} property not set to true for pool ${pool}"
        return 1
    fi

    return 0
}

# Checks for snapshots created in last 24h
# Returns 0 if recent snapshot found, 1 otherwise
check_recent_snapshots() {
    local pool=$1
    local current_timestamp=$(date +%s)

    zfs list -t snapshot -o name,creation -Hp | grep "^${pool}[@]" | while read -r snapshot creation; do
        # Calculate time difference
        time_diff=$((current_timestamp - creation))
        if [ $time_diff -lt 86400 ]; then
            echo "Recent snapshot found: $snapshot ($(date -d @${creation}))"
            BACKUP_STATS["recent_snapshot"]="$snapshot"
            BACKUP_STATS["recent_snapshot_time"]="$(date -d @${creation} '+%Y-%m-%d %H:%M:%S')"
            return 0
        fi
    done

    return 1
}

# Collect information about datasets
collect_dataset_info() {
    local pool=$1
    local datasets
    datasets=$(zfs list -r -o name -H "${pool}")
    
    BACKUP_STATS["total_datasets"]=$(echo "${datasets}" | wc -l)
    
    for dataset in ${datasets}; do
        # Get total snapshots for this dataset
        local snaps=$(zfs list -t snapshot -o name -H "${dataset}" 2>/dev/null | wc -l)
        DATASETS_INFO["${dataset},snaps"]="${snaps}"
        
        # Get last snapshot for this dataset
        local last_snap=""
        if [ "${snaps}" -gt 0 ]; then
            last_snap=$(zfs list -t snapshot -o name -H "${dataset}" | tail -1 | cut -d'@' -f2)
            DATASETS_INFO["${dataset},last_snap"]="${last_snap}"
        else
            DATASETS_INFO["${dataset},last_snap"]="N/A"
        fi
        
        # Get space used by this dataset
        local space=$(zfs list -o used -H "${dataset}")
        DATASETS_INFO["${dataset},space"]="${space}"
    done
}


# Function to categorize snapshots by type (monthly, weekly, daily)
categorize_snapshots() {
    local pool=$1
    local current_date=$(date +%Y%m%d)
    local one_week_ago=$(date -d "7 days ago" +%Y%m%d)
    local one_month_ago=$(date -d "30 days ago" +%Y%m%d)
    
    # Initialize monthly counters
    local current_month=$(date +%Y-%m)
    for i in {0..5}; do
        local month_key=$(date -d "$current_month-01 -$i month" +%Y-%m)
        MONTHLY_DISTRIBUTION["${month_key},monthly"]=0
        MONTHLY_DISTRIBUTION["${month_key},weekly"]=0
        MONTHLY_DISTRIBUTION["${month_key},daily"]=0
    done
    
    # Process all datasets in the pool
    for dataset in $(zfs list -r -o name -H "${pool}"); do
        local monthly_count=0
        local weekly_count=0
        local daily_count=0
        
        # Get all snapshots for this dataset
        zfs list -t snapshot -o name,creation -Hp "${dataset}" 2>/dev/null | 
        while read -r snapshot creation; do
            # Extract snapshot name and date
            local snap_name=$(echo "$snapshot" | cut -d'@' -f2)
            
            # Skip special snapshots (without date format)
            if [[ ! "$snap_name" =~ ^${pool}-[0-9]{14}$ ]]; then
                continue
            fi
            
            # Extract date in YYYYMMDD format
            local snap_date=$(echo "$snap_name" | grep -o "${pool}-[0-9]\{8\}" | cut -d'-' -f2)
            local snap_month=$(echo "$snap_date" | cut -c1-6 | sed 's/\(.\{4\}\)\(.\{2\}\)/\1-\2/')
            
            # Determine type based on patterns and dates
            local snap_type
            if [[ "$snap_date" -lt "$one_month_ago" && 
                  "$snap_date" =~ [0-9]{6}(0[1-9]|1[0-5]) ]]; then
                # Monthly snapshot (approx. mid-month and older than one month)
                snap_type="monthly"
                ((monthly_count++))
            elif [[ "$snap_date" -lt "$one_week_ago" && 
                   "$snap_date" -ge "$one_month_ago" ]]; then
                # Weekly snapshot (between one week and one month old)
                snap_type="weekly"
                ((weekly_count++))
            else
                # Daily snapshot (less than one week old)
                snap_type="daily"
                ((daily_count++))
            fi
            
            # Save type for this snapshot
            SNAPSHOT_TYPES["$snapshot"]="$snap_type"
            
            # Increment monthly count
            if [[ -n "$snap_month" ]]; then
                MONTHLY_DISTRIBUTION["${snap_month},${snap_type}"]=$((MONTHLY_DISTRIBUTION["${snap_month},${snap_type}"] + 1))
            fi
        done
        
        # Save counts for this dataset
        SNAPSHOT_COUNTS["${dataset},monthly"]=$monthly_count
        SNAPSHOT_COUNTS["${dataset},weekly"]=$weekly_count
        SNAPSHOT_COUNTS["${dataset},daily"]=$daily_count
    done
}


# Parse the output of zfs-autobackup for created and deleted snapshots
parse_autobackup_output() {
    local logfile=$1
    
    # Get counts of created and deleted snapshots
    local created_count=$(grep -c "Creating snapshots.*-[0-9]\{14\}" "${logfile}" || echo "0")
    local deleted_count=$(grep -c "Destroying" "${logfile}" || echo "0")
    
    BACKUP_STATS["snapshots_created"]="${created_count}"
    BACKUP_STATS["snapshots_deleted"]="${deleted_count}"
    
    # Populate array for created snapshots (useful for statistics)
    while read -r line; do
        local snap_name=$(echo "${line}" | grep -o '[^ ]*-[0-9]\{14\}')
        CREATED_SNAPSHOTS+=("${snap_name}")
    done < <(grep "Creating snapshots.*-[0-9]\{14\}" "${logfile}" || true)
    
    # Log basic stats
    echo "DEBUG: Found ${created_count} created and ${deleted_count} deleted snapshots" >> "${logfile}"
}


# Format time duration from seconds to a human readable format
format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))
    
    if [ "${minutes}" -eq 0 ]; then
        echo "${seconds} seconds"
    else
        echo "${minutes} minutes, ${remaining_seconds} seconds"
    fi
}

# Draw a table header with appropriate column sizes
draw_table_header() {
    local col1_width=$1
    local col2_width=$2
    local col3_width=$3
    local col4_width=$4
    
    printf "+%${col1_width}s+%${col2_width}s+%${col3_width}s+%${col4_width}s+\n" \
           "$(printf '%0.s-' $(seq 1 $col1_width))" \
           "$(printf '%0.s-' $(seq 1 $col2_width))" \
           "$(printf '%0.s-' $(seq 1 $col3_width))" \
           "$(printf '%0.s-' $(seq 1 $col4_width))"
           
    printf "| %-$((col1_width-2))s | %-$((col2_width-2))s | %-$((col3_width-2))s | %-$((col4_width-2))s |\n" \
           "Dataset" "Total Snaps" "Last Snapshot" "Space Used"
           
    printf "+%${col1_width}s+%${col2_width}s+%${col3_width}s+%${col4_width}s+\n" \
           "$(printf '%0.s-' $(seq 1 $col1_width))" \
           "$(printf '%0.s-' $(seq 1 $col2_width))" \
           "$(printf '%0.s-' $(seq 1 $col3_width))" \
           "$(printf '%0.s-' $(seq 1 $col4_width))"
}


# Draw a table row with appropriate column sizes
draw_table_row() {
    local dataset=$1
    local col1_width=$2
    local col2_width=$3
    local col3_width=$4
    local col4_width=$5
    
    local snaps="${DATASETS_INFO["${dataset},snaps"]}"
    local monthly="${SNAPSHOT_COUNTS["${dataset},monthly"]:-0}"
    local weekly="${SNAPSHOT_COUNTS["${dataset},weekly"]:-0}"
    local daily="${SNAPSHOT_COUNTS["${dataset},daily"]:-0}"
    local last_snap="${DATASETS_INFO["${dataset},last_snap"]}"
    local space="${DATASETS_INFO["${dataset},space"]}"
    
    # Format snapshot count with breakdown
    local snap_display="${snaps} (${monthly}M,${weekly}W,${daily}D)"
    
    # Truncate dataset name if too long
    local displayed_dataset="${dataset}"
    if [ ${#displayed_dataset} -gt $((col1_width-4)) ]; then
        displayed_dataset="${displayed_dataset:0:$((col1_width-7))}..."
    fi
    
    # Truncate last snapshot name if too long
    if [ ${#last_snap} -gt $((col3_width-4)) ]; then
        last_snap="${last_snap:0:$((col3_width-7))}..."
    fi
    
    printf "| %-$((col1_width-2))s | %-$((col2_width-2))s | %-$((col3_width-2))s | %-$((col4_width-2))s |\n" \
           "${displayed_dataset}" "${snap_display}" "${last_snap}" "${space}"
}


# Draw a simple statistics table
draw_stats_table() {
    echo
    echo "STATISTICS:"
    printf "+%-24s+%-15s+\n" "$(printf '%0.s-' $(seq 1 24))" "$(printf '%0.s-' $(seq 1 15))"
    printf "| %-22s | %-13s |\n" "Metric" "Value"
    printf "+%-24s+%-15s+\n" "$(printf '%0.s-' $(seq 1 24))" "$(printf '%0.s-' $(seq 1 15))"
    
    printf "| %-22s | %-13s |\n" "Total Datasets" "${BACKUP_STATS["total_datasets"]}"
    printf "| %-22s | %-13s |\n" "Snapshots Created" "${BACKUP_STATS["snapshots_created"]}"
    printf "| %-22s | %-13s |\n" "Snapshots Deleted" "${BACKUP_STATS["snapshots_deleted"]}"
    printf "| %-22s | %-13s |\n" "Operation Duration" "${BACKUP_STATS["duration"]}"
    
    printf "+%-24s+%-15s+\n" "$(printf '%0.s-' $(seq 1 24))" "$(printf '%0.s-' $(seq 1 15))"
}

# Generate a detailed summary report
generate_summary_report() {
    local pool=$1
    local status=$2
    local logfile=$3
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    BACKUP_STATS["duration"]="$(format_duration ${duration})"
    
    # Update dataset information
    collect_dataset_info "${pool}"

    # Update dataset information
    collect_dataset_info "${pool}"

    # Categorize snapshots
    categorize_snapshots "${pool}"

    # If this was a successful backup, parse the log for additional information
    if [ "${status}" = "COMPLETED" ]; then
        parse_autobackup_output "${logfile}"
    fi
    
    # Define table column widths
    local col1_width=32  # Dataset
    local col2_width=16  # Total Snaps
    local col3_width=32  # Last Snapshot
    local col4_width=15  # Space Used
    
    # Print summary header
    echo
    echo "===== BACKUP SUMMARY ($(date '+%Y-%m-%d %H:%M:%S')) ====="
    echo "POOL: ${pool}  |  Status: ${status}  |  Last backup: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Log file: ${logfile}"
    echo
    
    # Print dataset summary table if backup was not skipped
    if [ "${status}" != "✗ SKIPPED (Recent snapshot exists)" ]; then
        echo "DATASETS SUMMARY:"
        draw_table_header ${col1_width} ${col2_width} ${col3_width} ${col4_width}
        
        # List all datasets
        for dataset in $(zfs list -r -o name -H "${pool}"); do
            draw_table_row "${dataset}" ${col1_width} ${col2_width} ${col3_width} ${col4_width}
        done
        
        printf "+%${col1_width}s+%${col2_width}s+%${col3_width}s+%${col4_width}s+\n" \
               "$(printf '%0.s-' $(seq 1 $col1_width))" \
               "$(printf '%0.s-' $(seq 1 $col2_width))" \
               "$(printf '%0.s-' $(seq 1 $col3_width))" \
               "$(printf '%0.s-' $(seq 1 $col4_width))"
    else
        # ...código para cuando se omite el backup sin cambios...
    fi
    
    # Draw statistics table
    draw_stats_table
}

# Main backup function for a single pool
# Handles both backup execution and logging
# Skips if recent snapshot exists
log_backup() {
    local pool=$1
    local logfile="$LOG_DIR/${pool}_backup_${DATE}.log"
    local temp_error_file=$(mktemp)

    # Start logging from the beginning
    log_message "Processing pool: $pool" | tee -a "$logfile"
    log_message "- Checking for recent snapshots..." | tee -a "$logfile"

    # Check for recent snapshots first
    if check_recent_snapshots "$pool" > >(tee -a "$logfile") 2>&1; then
        log_message "- Recent snapshot found, skipping backup" | tee -a "$logfile"
        echo "✗ Skipping backup - Recent snapshot exists (less than 24h old)" | tee -a "$logfile"
        printf '\n\n' | tee -a "$logfile"
        
        # Generate summary report without execution summary header
        generate_summary_report "${pool}" "✗ SKIPPED (Recent snapshot exists)" "${logfile}" | tee -a "${logfile}"
        return 0
    fi

    log_message "- Starting backup" | tee -a "$logfile"
    log_message "- Log file: $logfile" | tee -a "$logfile"

    # Execute backup with full output capture
    if ! zfs-autobackup -v --clear-mountpoint --force --ssh-target "$REMOTE_HOST" "$pool" "$REMOTE_POOL_BASEPATH" > >(tee -a "$logfile") 2> >(tee -a "$temp_error_file" >&2); then
        log_message "- Backup failed" | tee -a "$logfile"
        cat "$temp_error_file" | tee -a "$logfile"
        printf '\n\n' | tee -a "$logfile"
        
        # Generate summary report without execution summary header
        generate_summary_report "${pool}" "✗ FAILED" "${logfile}" | tee -a "${logfile}"
        FAILED_POOLS+=("$pool")
    else
        log_message "- Backup completed successfully" | tee -a "$logfile"
        printf '\n' | tee -a "$logfile"
        
        # Generate summary report without execution summary header
        generate_summary_report "${pool}" "✓ COMPLETED" "${logfile}" | tee -a "${logfile}"
    fi

    rm -f "$temp_error_file"
}


# Removes log files that don't have matching snapshots
# Only processes logs older than current day
# Improved to better extract snapshot dates and provide more logging
clean_old_logs() {
    local pool=$1
    local current_date=$(date +%Y%m%d)
    
    log_message "Cleaning logs for $pool using match_snapshots policy"
    
    # Get dates of existing snapshots with improved pattern matching
    # This now properly extracts the YYYYMMDD portion from snapshot names
    local snapshot_dates=$(zfs list -t snapshot -o name -H "$pool" | 
                          grep -E "@${pool}-[0-9]{8}" | 
                          sed -E "s/.*@${pool}-([0-9]{8}).*/\1/" | 
                          sort -u)
    
    # Add logging to help troubleshoot snapshot date extraction
    local snapshot_count=$(echo "$snapshot_dates" | wc -w)
    log_message "Found $snapshot_count unique snapshot dates for $pool"
    
    # Check each log file
    find "$LOG_DIR" -name "${pool}_backup_*.log" | while read logfile; do
        # Extract the date portion (YYYYMMDD) from the log filename
        log_date=$(echo "$logfile" | grep -o '[0-9]\{8\}')
        
        # Skip if it's today's log
        if [ "$log_date" = "$current_date" ]; then
            continue
        fi
        
        # Only remove if it's an old log without corresponding snapshot
        if ! echo "$snapshot_dates" | grep -q "$log_date"; then
            log_message "Removing old log without matching snapshot: $logfile"
            rm "$logfile"
        else
            log_message "Keeping log that matches snapshot date: $logfile"
        fi
    done
}


# Main script execution
# Validates dependencies and pools
# Processes each pool and handles failures
main() {
    log_message "Starting ZFS backup process"
    log_message "Checking dependencies..."

    # Verify dependencies
    if ! check_dependencies; then
        log_message "Failed dependency check. Exiting."
        exit 1
    fi
    log_message "Dependencies OK"

    # Ensure log directory exists
    mkdir -p "$LOG_DIR" || {
        log_message "Error: Could not create log directory $LOG_DIR"
        exit 1
    }

    # Array for tracking failed pools
    declare -a FAILED_POOLS=()

    # Use specified pool or default list
    if [ $# -eq 1 ]; then
        if validate_pool "$1"; then
            POOLS=("$1")
        else
            exit 1
        fi
    else
        POOLS=("${SOURCE_POOLS[@]}")
    fi

    # Process each pool
    for pool in "${POOLS[@]}"; do
        log_backup "$pool"
        sleep 5  # Brief pause between pools
    done

    # Clean old logs
    for pool in "${POOLS[@]}"; do
        clean_old_logs "$pool"
    done

    # Final execution summary
    log_message "Backup process completed"
    echo
    echo "Execution Summary:"
    for pool in "${POOLS[@]}"; do
        if [[ " ${FAILED_POOLS[@]} " =~ " ${pool} " ]]; then
            echo "- $pool: ✗ Failed (/root/logs/${pool}_backup_${DATE}.log)"
        else
            echo "- $pool: ✓ Completed (/root/logs/${pool}_backup_${DATE}.log)"
        fi
    done
}

# Run main function with provided arguments
main "$@"
exit 0
