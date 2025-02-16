#!/usr/bin/env bash
#
# Copyright (c) 2024. All rights reserved.
# 
# Name: script_zfs-autobackup.sh
# Version: 1.0.5
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
set -x

# Global configuration
# Define remote hostname destination, requires ssh-key access or ~/.ssh/config host alias definition
REMOTE_HOST="zima01"
REMOTE_POOL_BASEPATH="WD181KFGX/BACKUPS"

# Define logs directory and date formats
LOG_DIR="/root/logs"
DATE=$(date +%Y%m%d)
TIMESTAMP="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Function to update timestamp
update_timestamp() {
    TIMESTAMP="[$(date '+%Y-%m-%d %H:%M:%S')]"
}

# Ensure PATH includes necessary directories
export PATH="/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# Source pools to backup if none specified
SOURCE_POOLS=(
    "spcca581117"
    "zserver01"
)

# Function to log messages with timestamp
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

# Check if required tools are installed
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

# Check for snapshots created in the last 24 hours
check_recent_snapshots() {
    local pool=$1
    local current_timestamp=$(date +%s)
    
    zfs list -t snapshot -o name,creation -Hp | grep "^${pool}[@]" | while read -r snapshot creation; do
        # Calculate time difference
        time_diff=$((current_timestamp - creation))
        if [ $time_diff -lt 86400 ]; then
            echo "Recent snapshot found: $snapshot ($(date -d @${creation}))"
            return 0
        fi
    done

    return 1
}

# Perform backup and log the process
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
        printf '\n\n\n\n' | tee -a "$logfile"
        echo "Execution Summary:" | tee -a "$logfile"
        echo "- $pool: ✗ Skipped (Recent snapshot exists)" | tee -a "$logfile"
        return 0
    fi

    log_message "- Starting backup" | tee -a "$logfile"
    log_message "- Log file: $logfile" | tee -a "$logfile"
    
    # Execute backup with full output capture
    if ! zfs-autobackup -v --clear-mountpoint --force --ssh-target "$REMOTE_HOST" "$pool" "$REMOTE_POOL_BASEPATH" > >(tee -a "$logfile") 2> >(tee -a "$temp_error_file" >&2); then
        log_message "- Backup failed" | tee -a "$logfile"
        cat "$temp_error_file" | tee -a "$logfile"
        printf '\n\n\n\n' | tee -a "$logfile"
        echo "Execution Summary:" | tee -a "$logfile"
        echo "- $pool: ✗ Failed" | tee -a "$logfile"
        FAILED_POOLS+=("$pool")
    else
        log_message "- Backup completed successfully" | tee -a "$logfile"
        printf '\n' | tee -a "$logfile"
        echo "Execution Summary:" | tee -a "$logfile"
        echo "- $pool: ✓ Completed" | tee -a "$logfile"
    fi
    
    rm -f "$temp_error_file"
}

# Clean old logs that don't have corresponding snapshots
clean_old_logs() {
    local pool=$1
    
    # Get dates of existing snapshots
    local snapshot_dates=$(zfs list -t snapshot -o name -H "$pool" | grep "@${pool}-" | cut -d'-' -f2 | cut -c1-8)
    local current_date=$(date +%Y%m%d)
    
    # Check each log file
    find "$LOG_DIR" -name "${pool}_backup_*.log" | while read logfile; do
        log_date=$(echo "$logfile" | grep -o '[0-9]\{8\}')
        
        # Skip if it's today's log
        if [ "$log_date" = "$current_date" ]; then
            continue
        fi
        
        # Only remove if it's an old log without corresponding snapshot
        if ! echo "$snapshot_dates" | grep -q "$log_date"; then
            log_message "Removing old log without snapshot: $logfile"
            rm "$logfile"
        fi
    done
}

# Main execution function
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