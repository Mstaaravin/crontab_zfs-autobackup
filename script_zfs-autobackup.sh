#!/bin/bash
# v1.0.0

# Define logs directory
LOG_DIR="/root/logs"
DATE=$(date +%Y%m%d)

# Define default pools to backup
DEFAULT_POOLS=(
    "spcca581117"
    "zserver01"
)

# Function to echo with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if zfs-autobackup is available
check_dependencies() {
    if ! command -v zfs-autobackup >/dev/null 2>&1; then
        log_message "Error: zfs-autobackup is not installed"
        return 1
    fi
    return 0
}

# Function to validate if a pool exists
validate_pool() {
    local pool=$1
    if ! zfs list "$pool" >/dev/null 2>&1; then
        log_message "Error: Pool $pool does not exist"
        return 1
    fi
    return 0
}

# Function to check recent snapshots (last 24h)
check_recent_snapshots() {
    local pool=$1
    local current_timestamp=$(date +%s)
    
    # Get list of snapshots for the specific pool only
    zfs list -t snapshot -o name,creation -Hp | grep "^${pool}[@]" | while read -r snapshot creation; do
        # If snapshot is less than 24h old (86400 seconds)
        time_diff=$((current_timestamp - creation))
        if [ $time_diff -lt 86400 ]; then
            echo "Recent snapshot found: $snapshot ($(date -d @${creation}))"
            return 0
        fi
    done

    return 1
}

# Function for backup and logging
log_backup() {
    local pool=$1
    local logfile="$LOG_DIR/${pool}_backup_${DATE}.log"
    local temp_error_file=$(mktemp)
    
    log_message "Processing pool: $pool"
    log_message "- Checking for recent snapshots..."
    
    echo "=== Starting backup process for pool $pool - $(date) ===" >> "$logfile"
    
    # Check for recent snapshots first
    if check_recent_snapshots "$pool" >> "$logfile" 2>&1; then
        log_message "- Recent snapshot found, skipping backup"
        echo "✗ Skipping backup - Recent snapshot exists (less than 24h old)" >> "$logfile"
        echo "===========================================" >> "$logfile"
        return 0
    fi

    log_message "- Starting backup"
    log_message "- Log file: $logfile"
    
    echo "No recent snapshots found, proceeding with backup" >> "$logfile"
    echo "Executing: zfs-autobackup --clear-mountpoint --force --ssh-target zima01 $pool WD181KFGX/BACKUPS" >> "$logfile"
    
    # Execute backup
    if ! zfs-autobackup --clear-mountpoint --force --ssh-target zima01 "$pool" WD181KFGX/BACKUPS > >(tee -a "$logfile") 2> >(tee -a "$temp_error_file" >&2); then
        log_message "- Backup failed"
        echo "✗ Error during pool backup - $(date)" >> "$logfile"
        echo "Error details:" >> "$logfile"
        cat "$temp_error_file" >> "$logfile"
        FAILED_POOLS+=("$pool")
    else
        log_message "- Backup completed successfully"
        echo "✓ Pool backup completed successfully - $(date)" >> "$logfile"
    fi
    
    rm -f "$temp_error_file"
    echo "===========================================" >> "$logfile"
}

# Function to clean logs without corresponding snapshots
clean_old_logs() {
    local pool=$1
    
    # Get dates of existing snapshots
    local snapshot_dates=$(zfs list -t snapshot -o name -H "$pool" | grep "@${pool}-" | cut -d'-' -f2 | cut -c1-8)
    
    # For each log file of this pool
    find "$LOG_DIR" -name "${pool}_backup_*.log" | while read logfile; do
        # Extract date from log filename
        log_date=$(echo "$logfile" | grep -o '[0-9]\{8\}')
        
        # Check if this date exists in snapshots
        if ! echo "$snapshot_dates" | grep -q "$log_date"; then
            log_message "Removing old log without snapshot: $logfile"
            rm "$logfile"
        fi
    done
}

# Main execution
main() {
    log_message "Starting ZFS backup process"
    log_message "Checking dependencies..."
    
    # Check dependencies first
    if ! check_dependencies; then
        log_message "Failed dependency check. Exiting."
        exit 1
    fi
    log_message "Dependencies OK"

    # Create logs directory if it doesn't exist
    mkdir -p "$LOG_DIR"

    # Array to store failed pools
    declare -a FAILED_POOLS=()

    # If a pool is specified as parameter, use it instead of the default list
    if [ $# -eq 1 ]; then
        if validate_pool "$1"; then
            POOLS=("$1")
        else
            exit 1
        fi
    else
        POOLS=("${DEFAULT_POOLS[@]}")
    fi

    # Execute backups sequentially for each pool
    for pool in "${POOLS[@]}"; do
        log_backup "$pool"
        # Add a small delay between pools
        sleep 5
    done

    # Clean logs for each pool
    for pool in "${POOLS[@]}"; do
        clean_old_logs "$pool"
    done

    # Print execution summary
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

# Run main function with all arguments
main "$@"
exit 0
