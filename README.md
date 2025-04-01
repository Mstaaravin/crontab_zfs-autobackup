# ZFS Bash Backup Script

Automated bash script for crontab execution that utilizes zfs-autobackup for snapshot management and replication.
The script handles logging, snapshot verification, and multiple pool backups.

> Note: This script is designed for crontab execution only. For detailed zfs-autobackup usage and documentation, please refer to the official repository: https://github.com/psy0rz/zfs_autobackup
> Also, this script was developed with the assistance of AI to enhance reliability and best practices.

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
  - [zfs-autobackup installation](#zfs-autobackup-installation-debian-12)
  - [SSH Configuration](#ssh-configuration)
  - [Required ZFS Configuration](#required-zfs-configuration)
  - [Verify ZFS Configuration](#verify-zfs-configuration)
- [Configuration](#configuration)
- [Usage](#usage)
- [Logs](#logs)
- [Verification](#verification)
- [Performance Considerations](#performance-considerations)
- [Scheduling](#scheduling)
- [Useful Links](#useful-links)
- [License](#license)

## Features
- Automated ZFS pool backup with snapshot management
- Configurable remote backup target
- Detailed logging with execution summaries
- Support for multiple pools or single pool backup
- Automatic cleanup of old logs
- Detailed backup reports in tabular format with statistics

## Prerequisites
- zfs-autobackup package installed
- SSH key authentication configured for remote target
- ZFS pool property configuration for autobackup

### zfs-autobackup installation (Debian 12)
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
Logs are stored in `/root/logs/`:
- Script execution logs: `/root/logs/cron_backup.log`
- Individual pool backup logs: `/root/logs/poolname_backup_YYYYMMDD_HHMM.log`

See [example log output](docs/log_output.md) for a complete execution example.

## Reports
Each backup operation generates a detailed report in tabular format at the end of execution. This provides a comprehensive overview of the backup operation including:

### Dataset Information Table
```
+--------------------------------+----------------+--------------------------------+-------------+-----------------------+
| Dataset                        | Total Snaps    | Last Snapshot                  | Space Used  | Deleted Snapshots     |
+--------------------------------+----------------+--------------------------------+-------------+-----------------------+
| zlhome01                       | 3              | zlhome01-20250331205942        | 24K         | -                     |
| zlhome01/HOME.cmiranda         | 16             | zlhome01-20250331205942        | 73.8G       | zlhome01-20250318...  |
```

### Statistics
```
+------------------------+-------------+
| Metric                 | Value       |
+------------------------+-------------+
| Total Datasets         | 9           |
| Snapshots Created      | 9           |
| Snapshots Deleted      | 7           |
| Operation Duration     | 77 seconds  |
+------------------------+-------------+
```

These reports provide valuable information for monitoring and auditing your backup operations, allowing you to easily track:
- Total number of snapshots per dataset
- Last snapshot timestamp
- Space usage by dataset
- Deleted snapshots during retention policy enforcement
- Overall operation statistics

## Verification
You can verify the backup process by comparing snapshots on both source and target:

### Source System
List all ZFS devices on my source system and list all ZFS snapshots on zlhome01/HOME.cmiranda

```bash
root@lhome01:~# zfs list 
NAME                                       USED  AVAIL     REFER  MOUNTPOINT
zlhome01                                  1.90T   904G       24K  none
zlhome01/HOME.cmiranda                    1.43T   904G     1.34T  /home/cmiranda
zlhome01/HOME.root                        15.5G   904G     15.4G  /root
zlhome01/etc.libvirt.qemu                  402K   904G     76.5K  /etc/libvirt/qemu/
zlhome01/var.lib.docker                    132G   904G     26.2G  /var/lib/docker
zlhome01/var.snap.lxd                     45.7G   904G     12.7G  /var/snap/lxd


root@lhome01:~# zfs list -t snapshot zlhome01/HOME.cmiranda
NAME                                             USED  AVAIL     REFER  MOUNTPOINT
zlhome01/HOME.cmiranda@zlhome01-20241115013705  14.5G      -     1.25T  -
zlhome01/HOME.cmiranda@zlhome01-20241214223058  14.7G      -     1.27T  -
zlhome01/HOME.cmiranda@zlhome01-20250113180001  9.63G      -     1.32T  -
zlhome01/HOME.cmiranda@zlhome01-20250123180001  5.48G      -     1.33T  -
zlhome01/HOME.cmiranda@zlhome01-20250130195652  6.73G      -     1.34T  -
zlhome01/HOME.cmiranda@zlhome01-20250206181002  4.91G      -     1.33T  -
zlhome01/HOME.cmiranda@zlhome01-20250209181002  2.54G      -     1.33T  -
zlhome01/HOME.cmiranda@zlhome01-20250210181902  2.11G      -     1.33T  -
zlhome01/HOME.cmiranda@zlhome01-20250211181002  2.68G      -     1.33T  -
zlhome01/HOME.cmiranda@zlhome01-20250213190813  3.22G      -     1.34T  -
zlhome01/HOME.cmiranda@zlhome01-20250214152941  2.79G      -     1.34T  -
zlhome01/HOME.cmiranda@zlhome01-20250215185238   905M      -     1.34T  -
zlhome01/HOME.cmiranda@zlhome01-20250215232707   155M      -     1.34T  -
zlhome01/HOME.cmiranda@zlhome01-20250216004001   146M      -     1.34T  -
zlhome01/HOME.cmiranda@zlhome01-20250216143501   134M      -     1.34T  -
zlhome01/HOME.cmiranda@zlhome01-20250216195101  62.4M      -     1.34T  -
```

### Target System
List all ZFS snapshots on for zlhome01/HOME.cmiranda on remote host
```bash
root@zima01:~# zfs list -t snapshot WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda
NAME                                                               USED  AVAIL     REFER  MOUNTPOINT
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20241115013705  15.1G      -     1.26T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20241214223058  15.2G      -     1.27T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250113180001  10.0G      -     1.32T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250123180001  5.69G      -     1.33T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250130195652  6.94G      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250206181002  5.10G      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250209181002  2.64G      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250210181902  2.20G      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250211181002  2.80G      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250213190813  3.35G      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250214152941  2.87G      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250215185238   937M      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250215232707   160M      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250216004001   152M      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250216143501   143M      -     1.34T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250216195101     0B      -     1.34T  -

```



## Performance Considerations
- Uses hardware-accelerated AES-GCM encryption for optimal SSH transfer speeds
- Configurable cipher selection through SSH config
- Automatically handles incremental snapshots to minimize data transfer

## Scheduling
Configure root's crontab to run daily at desired time:
```bash
# Run daily at 14:35
35 14 * * * /root/scripts/backup_zfs.sh > /root/logs/cron_backup.log 2>&1
```

## Useful Links
- [ZFS Autobackup Official Repository](https://github.com/psy0rz/zfs_autobackup)
- [Automating ZFS Snapshots for Peace of Mind](https://it-notes.dragas.net/2024/08/21/automating-zfs-snapshots-for-peace-of-mind/)
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Benchmark SSH Ciphers](https://gbe0.com/posts/linux/server/benchmark-ssh-ciphers/)
- [Benchmarking SSH Ciphers](https://bash-prompt.net/guides/bash-ssh-ciphers/)


## License
MIT
