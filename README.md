# ZFS Bash Backup Script

Automated bash script utilizing zfs-autobackup tool for snapshot management and replication.

## Features
- Automated ZFS pool backup with snapshot management
- Configurable remote backup target
- Detailed logging with execution summaries
- Support for multiple pools or single pool backup
- Automatic cleanup of old logs

## Prerequisites
- zfs-autobackup package installed
- SSH key authentication configured for remote target
- ZFS pool property configuration for autobackup

### zfs-autonbackup installation (Debian 12)
```bash
:~# apt install pipx -y
:~# pipx install zfs-autobackup
:~# pipx ensurepath
:~# pipx completions
:~# eval "$(register-python-argcomplete pipx)"
```

### SSH Configuration
Create or edit `/root/.ssh/config`:
```
Host zima01
    HostName 172.16.254.5
    IdentityFile ~/.ssh/id_rsa
    Ciphers aes128-gcm@openssh.com
```

The `Ciphers aes128-gcm@openssh.com` configuration optimizes SSH bandwidth by using hardware-accelerated AES-GCM encryption, which significantly improves transfer speeds compared to default ciphers.

### Required ZFS Configuration
Each pool to be backed up needs the autobackup property set:
```bash
:~# zfs set autobackup:poolname=true poolname
# Example:
:~# zfs set autobackup:zlhome01=true zlhome01
```

### Verify ZFS Configuration
Verify autobackup property is set for the pool and its datasets:
```bash
:~# zfs get all | grep autobackup
```

Example output:
```
zlhome01                       autobackup:zlhome01   true   local
zlhome01/HOME.cmiranda        autobackup:zlhome01   true   inherited from zlhome01
zlhome01/HOME.root           autobackup:zlhome01   true   inherited from zlhome01
```
The property should be 'local' on the pool and 'inherited' on datasets.

## Configuration
Edit the script to set:
- `REMOTE_HOST`: Target host for backups (matches SSH config Host)
- `LOG_DIR`: Directory for log files
- `DEFAULT_POOLS`: Array of pools to backup when no specific pool is provided

## Usage
```bash
:~# ./backup_zfs.sh [pool_name]
```

### Examples
```bash
# Backup all configured pools
:~# ./backup_zfs.sh

# Backup specific pool
:~# ./backup_zfs.sh zlhome01
```

## Logs
Logs are stored in `/root/logs/` by default:
- Script execution logs: `/root/logs/cron_backup.log`
- Individual pool backup logs: `/root/logs/poolname_backup_YYYYMMDD.log`

## Performance Considerations
- Uses hardware-accelerated AES-GCM encryption for optimal SSH transfer speeds
- Configurable cipher selection through SSH config
- Automatically handles incremental snapshots to minimize data transfer

## License
MIT
