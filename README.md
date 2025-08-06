# ZFS Backup Automation Tool (Powered by zfs-autobackup)

A comprehensive bash wrapper script for zfs-autobackup that extends its functionality with automated scheduling, detailed reporting, snapshot categorization, and intelligent log management. This tool leverages the powerful snapshot and replication capabilities of zfs-autobackup while adding enterprise-grade reporting and management features.

> Note: This script acts as a controller for the zfs-autobackup utility, which must be installed separately. For detailed zfs-autobackup usage and documentation, please refer to the official repository: https://github.com/psy0rz/zfs_autobackup <br />
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
- [Reports](#reports)
- [Verification](#verification)
- [Snapshot Categorization](#snapshot-categorization)
- [Performance Considerations](#performance-considerations)
- [Automatic Execution with Crontab](#automatic-execution-with-crontab)
- [Useful Links](#useful-links)
- [License](#license)

## Features
- Automated ZFS pool backup with snapshot management
- Configurable remote backup target
- Detailed logging with execution summaries
- Support for multiple pools or single pool backup
- Automatic cleanup of old logs
- Detailed backup reports in tabular format with statistics
- Snapshot categorization by age (monthly, weekly, daily)
- Monthly distribution tracking of snapshots

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
    Ciphers aes128-gcm@openssh.com
    Compression no
    IPQoS throughput
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
- `REMOTE_POOL_BASEPATH`: Base path on the remote host where backups will be stored
- `LOG_DIR`: Directory for log files
- `SOURCE_POOLS`: Array of pools to backup when no specific pool is provided

For the `SOURCE_POOLS` array, add each pool on a new line within the parentheses:

```bash
# Source pools to backup if none specified
SOURCE_POOLS=(
    "zlhome01"
    "tank"
)
```

## Usage
```bash
:~# ./script_zfs-autobackup.sh [pool_name]
```

The script can operate in two modes:

1. **Multiple Pool Mode**: When run without arguments, it processes all pools listed in the `SOURCE_POOLS` array defined in the script.
2. **Single Pool Mode**: When a pool name is provided as an argument, it processes only that specific pool, regardless of what's configured in the `SOURCE_POOLS` array.

### Examples
```bash
# Backup all pools configured in SOURCE_POOLS array
:~# ./script_zfs-autobackup.sh

# Backup only the specified pool (overrides SOURCE_POOLS configuration)
:~# ./script_zfs-autobackup.sh zlhome01
```

This allows you to have a standard set of pools configured for regular backups while maintaining the flexibility to target a specific pool when needed.

## Logs
Logs are stored in `/root/logs/`:
- Script execution logs: `/root/logs/cron_backup.log`
- Individual pool backup logs: `/root/logs/poolname_backup_YYYYMMDD_HHMM.log`

See [example log output](docs/log_output.md) for a complete execution example.

## Reports
Each backup operation generates a detailed report in tabular format at the end of execution. This provides a comprehensive overview of the backup operation, including:

### Dataset Information Table
Starting v1.0.9, dataset information includes space usage and improved formatting:
```
+--------------------------------+----------------+--------------------------------+---------------+
| Dataset                        | Total Snaps    | Last Snapshot                  | Space Used    |
+--------------------------------+----------------+--------------------------------+---------------+
| zlhome01                       | 3              | zlhome01-20250331205942        | 24K           |
| zlhome01/HOME.cmiranda         | 16             | zlhome01-20250331205942        | 73.8G         |
```

### Statistics
```
+------------------------+---------------+
| Metric                 | Value         |
+------------------------+---------------+
| Total Datasets         | 9             |
| Snapshots Created      | 9             |
| Snapshots Deleted      | 7             |
| Operation Duration     | 77 seconds    |
+------------------------+---------------+
```

These reports provide valuable information for monitoring and auditing your backup operations, allowing you to easily track total snapshots, space usage, and operation statistics.

## Verification
You can verify the backup process by comparing snapshots on both source and target, and by reviewing the comprehensive backup reports. Below are real-world examples from a production environment showing what to look for when verifying your backups:

### Source System
The following example shows a ZFS pool with multiple datasets and their respective snapshots. This is what you would check on your source system:

```bash
root@lhome01:~/scripts# zfs list 
NAME                                USED  AVAIL     REFER  MOUNTPOINT
usbzfs01                           9.63M   231G     9.46M  /usbzfs01
zlhome01                           2.10T   704G       24K  none
zlhome01/HOME.cmiranda             1.93T   704G     1.66T  /home/cmiranda
zlhome01/HOME.root                 15.8G   704G     15.7G  /root
zlhome01/LIBVIRT.W10.optiplex9020  21.2G   704G     18.6G  -
zlhome01/etc.libvirt.qemu           454K   704G       49K  /etc/libvirt/qemu/
zlhome01/var.lib.docker            89.8G   704G     11.2G  /var/lib/docker
zlhome01/var.snap.lxd              43.5G   704G     13.4G  /var/snap/lxd


root@lhome01:~/scripts# zfs list -t snapshot zlhome01/HOME.cmiranda
NAME                                                USED  AVAIL     REFER  MOUNTPOINT
zlhome01/HOME.cmiranda@zlhome01-20241115013705     14.5G      -     1.25T  -
zlhome01/HOME.cmiranda@zlhome01-20241214223058     14.7G      -     1.27T  -
zlhome01/HOME.cmiranda@zlhome01-20250113180001     13.6G      -     1.32T  -
zlhome01/HOME.cmiranda@zlhome01-20250211181002     11.2G      -     1.33T  -
zlhome01/HOME.cmiranda@zlhome01-20250313180811     10.6G      -     1.35T  -
zlhome01/HOME.cmiranda@to_spcc1117-20250404180231  91.9M      -     1.73T  -
zlhome01/HOME.cmiranda@usbdisk-20250404181119      84.8M      -     1.73T  -
zlhome01/HOME.cmiranda@zlhome01-20250505185145     1.66G      -     1.69T  -
zlhome01/HOME.cmiranda@zlhome01-20250506173148     1021M      -     1.69T  -
zlhome01/HOME.cmiranda@zlhome01-20250507214850      783M      -     1.68T  -
zlhome01/HOME.cmiranda@zlhome01-20250508230441      629M      -     1.68T  -
zlhome01/HOME.cmiranda@zlhome01-20250509162222      886M      -     1.69T  -
zlhome01/HOME.cmiranda@zlhome01-20250509191838      948M      -     1.69T  -
zlhome01/HOME.cmiranda@zlhome01-20250510003648      512M      -     1.68T  -
zlhome01/HOME.cmiranda@zlhome01-20250510020318     66.7M      -     1.68T  -
zlhome01/HOME.cmiranda@zlhome01-20250510025059     63.3M      -     1.69T  -
zlhome01/HOME.cmiranda@zlhome01-20250510030653     25.2M      -     1.69T  -
zlhome01/HOME.cmiranda@zlhome01-20250510031332     28.1M      -     1.66T  -
zlhome01/HOME.cmiranda@zlhome01-20250510230007      582M      -     1.66T  -
zlhome01/HOME.cmiranda@zlhome01-20250511011637     45.0M      -     1.66T  -
```

### Target System
After running the backup, you should verify that snapshots appear on the target system. Below is what a successful backup looks like on the remote host, showing the same snapshots that were transferred from the source:

```bash
cmiranda@zima01:~$ zfs list -t snapshot WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda
NAME                                                               USED  AVAIL     REFER  MOUNTPOINT
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20241115013705  11.1G      -     1.20T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20241214223058  12.4G      -     1.21T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250113180001  10.5G      -     1.26T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250211181002  8.57G      -     1.28T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250313180811  9.80G      -     1.29T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250505185145  1.79G      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250506173148  1.09G      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250507214850   852M      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250508230441   676M      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250509162222   907M      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250509191838   974M      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250510003648   521M      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250510020318  68.9M      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250510025059  65.5M      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250510030653  25.7M      -     1.64T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250510031332  29.0M      -     1.61T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250510230007   603M      -     1.61T  -
WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250511011637     0B      -     1.61T  -
```

When verifying your backups, ensure that:
1. All datasets that should be backed up appear on the target system
2. The number and timestamps of snapshots match between source and target
3. No errors are reported in the logs
4. Recent snapshots (especially the last one) are present on both systems

The backup summary report provides an additional verification method by showing a comprehensive overview of all datasets, snapshots, and operations in a single view.

## Snapshot Categorization

Starting with v1.0.10, the script now includes advanced snapshot categorization and reporting capabilities:

### Enhanced Dataset Summary
The dataset summary now includes a breakdown of snapshots by type:
```
+--------------------------------+----------------+--------------------------------+---------------+
| Dataset                        | Total Snaps    | Last Snapshot                  | Space Used    |
+--------------------------------+----------------+--------------------------------+---------------+
| zlhome01                       | 3 (1M,0W,0D)   | usbdisk-20250404181119         | 2.10T         |
| zlhome01/HOME.cmiranda         | 20 (5M,0W,13D) | zlhome01-20250511011637        | 1.93T         |
| zlhome01/HOME.root             | 20 (5M,0W,13D) | zlhome01-20250511011637        | 15.8G         |
```
The format `Total (XM,YW,ZD)` shows:
- XM = Monthly snapshots (older than 1 month)
- YW = Weekly snapshots (between 1 week and 1 month old)
- ZD = Daily snapshots (less than 1 week old)

### Snapshot Distribution Table
A new table shows the distribution of snapshots by month and type:
```
SNAPSHOT DISTRIBUTION:
+--------------------+----------+----------+----------+
| Date Range         | Monthly  | Weekly   | Daily    |
+--------------------+----------+----------+----------+
| 2025-05 (Current)  | 0        | 0        | 60       |
| 2025-04            | 4        | 0        | 0        |
| 2025-03            | 5        | 0        | 0        |
| 2025-02            | 5        | 0        | 0        |
| 2025-01            | 5        | 0        | 0        |
| 2024-12            | 5        | 0        | 0        |
+--------------------+----------+----------+----------+
```

### Retention Policy Documentation
The report now includes a documentation of the configured retention policy:
```
RETENTION POLICY:
- Daily snapshots: Keep last 10, retain for 1 week
- Weekly snapshots: Keep every 1 week, retain for 1 month
- Monthly snapshots: Keep every 1 month, retain for 1 year
```

### Enhanced Statistics
The statistics section now includes counts by snapshot type:
```
STATISTICS:
+------------------------+---------------+
| Metric                 | Value         |
+------------------------+---------------+
| Total Datasets         | 7             |
| Snapshots Created      |               |
| Snapshots Deleted      |               |
| Monthly Snapshots      | 29            |
| Weekly Snapshots       | 0             |
| Daily Snapshots        | 60            |
| Operation Duration     | 1 minutes, 24 seconds |
+------------------------+---------------+
```

### Full Backup Summary Example
```
===== BACKUP SUMMARY (2025-08-06 20:01:09) =====
DATASETS SUMMARY:
+--------------------------------+----------------+--------------------------------+---------------+
| Dataset                        | Total Snaps    | Last Snapshot                  | Space Used    |
+--------------------------------+----------------+--------------------------------+---------------+
| zlhome01                       | 3 (3M,0W,0D)   | usbdisk-20250404181119         | 2.42T         |
| zlhome01/HOME.cmiranda         | 27 (10M,3W,14D) | zlhome01-20250806200053        | 2.10T         |
| zlhome01/HOME.root             | 27 (10M,3W,14D) | zlhome01-20250806200053        | 16.0G         |
| zlhome01/LIBVIRT.W10.opti...   | 17 (3M,7W,7D)  | zlhome01-20250806180603        | 72.5G         |
| zlhome01/VIRT.bookworm01       | 14 (1M,6W,7D)  | zlhome01-20250806180603        | 5.74G         |
| zlhome01/etc.libvirt.qemu      | 23 (9M,6W,8D)  | zlhome01-20250806180603        | 624K          |
| zlhome01/var.lib.docker        | 23 (10M,6W,7D) | zlhome01-20250806180603        | 188G          |
| zlhome01/var.snap.lxd          | 28 (11M,3W,14D) | zlhome01-20250806200053        | 45.0G         |
+--------------------------------+----------------+--------------------------------+---------------+

SNAPSHOT DISTRIBUTION:
+--------------------+----------+----------+----------+
| Date Range         | Monthly  | Weekly   | Daily    |
+--------------------+----------+----------+----------+
| 2025-08 (Current)  | 0        | 0        | 15       |
| 2025-07            | 1        | 7        | 1        |
| 2025-06            | 1        | 0        | 0        |
| 2025-05            | 3        | 0        | 0        |
| 2025-04            | 3        | 0        | 0        |
| 2025-03            | 1        | 0        | 0        |
+--------------------+----------+----------+----------+

RETENTION POLICY:
- Daily snapshots: Keep last 10, retain for 1 week
- Weekly snapshots: Keep every 1 week, retain for 1 month
- Monthly snapshots: Keep every 1 month, retain for 1 year

STATISTICS:
+------------------------+---------------+
| Metric                 | Value         |
+------------------------+---------------+
| Total Datasets         | 8             |
| Snapshots Created      |               |
| Snapshots Deleted      |               |
| Monthly Snapshots      | 57            |
| Weekly Snapshots       | 34            |
| Daily Snapshots        | 71            |
| Operation Duration     | 16s           |
+------------------------+---------------+

LOG ROTATION:
[2025-08-06 20:01:09] Cleaning logs for zlhome01 using match_snapshots policy
[2025-08-06 20:01:09] Found 25 unique snapshot dates for zlhome01 (recursive search)
[2025-08-06 20:01:09] Sample extracted dates: 20241115 20241214 20250113 20250211 20250313 
[2025-08-06 20:01:09] Date range: 20241115 to 20250806
[2025-08-06 20:01:09] Keeping log that matches snapshot date 20250805: /root/logs/zlhome01_backup_20250805_2316.log
[2025-08-06 20:01:09] Keeping log that matches snapshot date 20250730: /root/logs/zlhome01_backup_20250730_0904.log
[2025-08-06 20:01:09] Keeping log that matches snapshot date 20250803: /root/logs/zlhome01_backup_20250803_1800.log
[2025-08-06 20:01:09] Keeping current day log: /root/logs/zlhome01_backup_20250806_1942.log
[2025-08-06 20:01:09] Keeping log that matches snapshot date 20250719: /root/logs/zlhome01_backup_20250719_1800.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250726: /root/logs/zlhome01_backup_20250726_1800.log
[2025-08-06 20:01:10] Keeping current day log: /root/logs/zlhome01_backup_20250806_1853.log
[2025-08-06 20:01:10] Keeping current day log: /root/logs/zlhome01_backup_20250806_1854.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250804: /root/logs/zlhome01_backup_20250804_1800.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250731: /root/logs/zlhome01_backup_20250731_1800.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250802: /root/logs/zlhome01_backup_20250802_2201.log
[2025-08-06 20:01:10] Keeping current day log: /root/logs/zlhome01_backup_20250806_1806.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250707: /root/logs/zlhome01_backup_20250707_1930.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250709: /root/logs/zlhome01_backup_20250709_1920.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250725: /root/logs/zlhome01_backup_20250725_1800.log
[2025-08-06 20:01:10] Keeping current day log: /root/logs/zlhome01_backup_20250806_1946.log
[2025-08-06 20:01:10] Keeping current day log: /root/logs/zlhome01_backup_20250806_2000.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250804: /root/logs/zlhome01_backup_20250804_2030.log
[2025-08-06 20:01:10] Keeping current day log: /root/logs/zlhome01_backup_20250806_1951.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250710: /root/logs/zlhome01_backup_20250710_1920.log
[2025-08-06 20:01:10] Keeping current day log: /root/logs/zlhome01_backup_20250806_1849.log
[2025-08-06 20:01:10] Keeping current day log: /root/logs/zlhome01_backup_20250806_1851.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250801: /root/logs/zlhome01_backup_20250801_1800.log
[2025-08-06 20:01:10] Keeping log that matches snapshot date 20250724: /root/logs/zlhome01_backup_20250724_1800.log
[2025-08-06 20:01:10] Log cleanup completed for zlhome01: processed=24, removed=0, kept=24

POOL: zlhome01  |  Status: ✓ COMPLETED  |  Last backup: 2025-08-06 20:01:09
Log file: /root/logs/zlhome01_backup_20250806_2000.log
```

This enhanced reporting makes it easy to:
1. Verify that your retention policies are working correctly
2. Track the distribution of snapshots across time periods
3. Ensure you have the right balance of short-term and long-term backups

## Performance Considerations
- Uses hardware-accelerated AES-GCM encryption for optimal SSH transfer speeds
- Configurable cipher selection through SSH config
- Automatically handles incremental snapshots to minimize data transfer

## Automatic Execution with Crontab
Configure the root user's crontab to automatically run the backup script at your desired time:
```bash
# Run daily at 23:00hs
0 23 * * * PATH=$PATH:/root/.local/bin /root/scripts/backup_zfs.sh > /root/logs/cron_backup.log 2>&1
```
Make sure the script has executable permissions:
```bash
chmod +x /root/scripts/backup_zfs.sh
```


## Useful Links
- [ZFS Autobackup Official Repository](https://github.com/psy0rz/zfs_autobackup)
- [Automating ZFS Snapshots for Peace of Mind](https://it-notes.dragas.net/2024/08/21/automating-zfs-snapshots-for-peace-of-mind/)
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Benchmark SSH Ciphers](https://gbe0.com/posts/linux/server/benchmark-ssh-ciphers/)
- [Benchmarking SSH Ciphers](https://bash-prompt.net/guides/bash-ssh-ciphers/)


## License
MIT