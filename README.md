# ZFS Bash Backup Script

Automated bash script for crontab execution that utilizes zfs-autobackup for snapshot management and replication.
The script handles logging, snapshot verification, and multiple pool backups.

⚠️ This script is designed for crontab execution only. For detailed zfs-autobackup usage and documentation, please refer to the official repository: https://github.com/psy0rz/zfs_autobackup

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
zlhome01                     autobackup:zlhome01   true   local
zlhome01/HOME.cmiranda       autobackup:zlhome01   true   inherited from zlhome01
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
:~# ./script_zfs-autobackup.sh [pool_name]
```

### Examples
```bash
# Backup all configured pools
:~# ./script_zfs-autobackup.sh

# Backup specific pool
:~# ./script_zfs-autobackup.sh zlhome01
```

## Logs
Logs are stored in `/root/logs/` by default:
- Script execution logs: `/root/logs/cron_backup.log`
- Individual pool backup logs: `/root/logs/poolname_backup_YYYYMMDD.log`

## Performance Considerations
- Uses hardware-accelerated AES-GCM encryption for optimal SSH transfer speeds
- Configurable cipher selection through SSH config
- Automatically handles incremental snapshots to minimize data transfer

## Scheduling
Configure root's crontab to run daily at 23:00:
```bash
:~# crontab -l
0 23 * * * PATH=$PATH:/root/.local/bin /root/script_zfs-autobackup.sh > /root/logs/cron_backup.log 2>&1
```
Note: Include PATH to ensure zfs-autobackup is accessible in cron environment.

## Useful Links
- [ZFS Autobackup Official Repository](https://github.com/psy0rz/zfs_autobackup)
- [Automating ZFS Snapshots for Peace of Mind](https://it-notes.dragas.net/2024/08/21/automating-zfs-snapshots-for-peace-of-mind/)
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)


## License
MIT
