## Log Example
Below is an example of a successful backup execution log:

```log
[2025-02-16 19:51:01] Processing pool: zlhome01
[2025-02-16 19:51:01] - Checking for recent snapshots...
+ local pool=zlhome01
++ date +%s
+ local current_timestamp=1739746261
+ zfs list -t snapshot -o name,creation -Hp
+ grep '^zlhome01[@]'
+ read -r snapshot creation
+ time_diff=8100836
+ '[' 8100836 -lt 86400 ']'
+ read -r snapshot creation
+ return 1
[2025-02-16 19:51:01] - Starting backup
[2025-02-16 19:51:01] - Log file: /root/logs/zlhome01_backup_20250216_1951.log
  zfs-autobackup v3.2 - (c)2022 E.H.Eefting (edwin@datux.nl)
  
  
  Selecting dataset property : autobackup:zlhome01
  Snapshot format            : zlhome01-%Y%m%d%H%M%S
  Timezone                   : Local
  Hold name                  : zfs_autobackup:zlhome01
  
  #### Source settings
  [Source] Keep the last 10 snapshots.
  [Source] Keep every 1 day, delete after 1 week.
  [Source] Keep every 1 week, delete after 1 month.
  [Source] Keep every 1 month, delete after 1 year.
  
  #### Selecting
  [Source] zlhome01: Selected
  [Source] zlhome01/HOME.cmiranda: Selected
  [Source] zlhome01/HOME.root: Selected
  [Source] zlhome01/LIBVIRT.ORALAB.LMDE6: Selected
  [Source] zlhome01/LIBVIRT.ORAWORK.ol8neo50s: Selected
  [Source] zlhome01/LIBVIRT.ORAWORK.w11optiplex9020: Selected
  [Source] zlhome01/etc.libvirt.qemu: Selected
  [Source] zlhome01/var.lib.docker: Selected
  [Source] zlhome01/var.snap.lxd: Selected
  
  #### Snapshotting
  [Source] zlhome01: No changes since zlhome01-20241115013705
  [Source] zlhome01/LIBVIRT.ORALAB.LMDE6: No changes since zlhome01-20241119190253
  [Source] zlhome01/LIBVIRT.ORAWORK.ol8neo50s: No changes since zlhome01-20250215232707
  [Source] zlhome01/LIBVIRT.ORAWORK.w11optiplex9020: No changes since zlhome01-20250215232707
  [Source] zlhome01/etc.libvirt.qemu: No changes since zlhome01-20250215232707
  [Source] zlhome01/var.lib.docker: No changes since zlhome01-20250215232707
  [Source] Creating snapshots zlhome01-20250216195101 in pool zlhome01
  
  #### Target settings
  [Target] SSH to: zima01
  [Target] Keep the last 10 snapshots.
  [Target] Keep every 1 day, delete after 1 week.
  [Target] Keep every 1 week, delete after 1 month.
  [Target] Keep every 1 month, delete after 1 year.
  [Target] Receive datasets under: WD181KFGX/BACKUPS
  
  #### Synchronising
  [Source] zlhome01: sending to WD181KFGX/BACKUPS/zlhome01
  [Source] zlhome01/HOME.cmiranda: sending to WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda
  [Source] zlhome01/HOME.cmiranda@zlhome01-20250208181001: Destroying
  [Target] WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250208181001: Destroying
  [Target] WD181KFGX/BACKUPS/zlhome01/HOME.cmiranda@zlhome01-20250216195101: receiving incremental
  [Source] zlhome01/HOME.root: sending to WD181KFGX/BACKUPS/zlhome01/HOME.root
  [Source] zlhome01/HOME.root@zlhome01-20250208181001: Destroying
  [Target] WD181KFGX/BACKUPS/zlhome01/HOME.root@zlhome01-20250208181001: Destroying
  [Target] WD181KFGX/BACKUPS/zlhome01/HOME.root@zlhome01-20250216195101: receiving incremental
  [Source] zlhome01/LIBVIRT.ORALAB.LMDE6: sending to WD181KFGX/BACKUPS/zlhome01/LIBVIRT.ORALAB.LMDE6
  [Source] zlhome01/LIBVIRT.ORAWORK.ol8neo50s: sending to WD181KFGX/BACKUPS/zlhome01/LIBVIRT.ORAWORK.ol8neo50s
  [Source] zlhome01/LIBVIRT.ORAWORK.w11optiplex9020: sending to WD181KFGX/BACKUPS/zlhome01/LIBVIRT.ORAWORK.w11optiplex9020
  [Source] zlhome01/etc.libvirt.qemu: sending to WD181KFGX/BACKUPS/zlhome01/etc.libvirt.qemu
  [Source] zlhome01/var.lib.docker: sending to WD181KFGX/BACKUPS/zlhome01/var.lib.docker
  [Source] zlhome01/var.snap.lxd: sending to WD181KFGX/BACKUPS/zlhome01/var.snap.lxd
  [Source] zlhome01/var.snap.lxd@zlhome01-20250208181001: Destroying
  [Target] WD181KFGX/BACKUPS/zlhome01/var.snap.lxd@zlhome01-20250208181001: Destroying
  [Target] WD181KFGX/BACKUPS/zlhome01/var.snap.lxd@zlhome01-20250216195101: receiving incremental
  
  #### All operations completed successfully
[2025-02-16 19:51:16] - Backup completed successfully

Execution Summary:
- zlhome01: ✓ Completed

```

> Note: The log output has been truncated for brevity. Actual logs will show all datasets being processed.