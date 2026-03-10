# lustrebackup-mgs

Lustre snapshot backup Management Service (MGS) tools.

Developed by the [Science HPC Center at UCPH](https://www.science.ku.dk/english/research/). Licensed under the [GNU General Public License v2](LICENSE).

## Overview

This project provides bash wrapper scripts around Lustre's `lctl snapshot` commands. It solves a core limitation: Lustre cannot handle dynamic changes to `ldev.conf` between snapshot operations. These scripts atomically swap the `ldev.conf` symlink to the correct snapshot-specific configuration before each `lctl` call, then restore it afterwards — all protected by `flock` to prevent race conditions.

## Requirements

- Lustre filesystem with `lctl` available
- An existing `/etc/ldev.conf`
- `bash`, `flock`, standard Unix utilities
- `logger` (for the SSH command validator)

## Installation

Copy files to their respective system locations:

```bash
cp lib/lustre_snapshot_ldev_init.sh /usr/local/lib/
cp sbin/lctl_snapshot_*.sh          /usr/local/sbin/
cp sbin/lctl_ssh_command_validator.sh /usr/local/sbin/
```

On first use, `ldev_conf_init` will migrate `/etc/ldev.conf` into `/etc/ldev/ldev.conf` and replace the original with a symlink. Snapshot-specific configs are stored as `/etc/ldev/<fsname>/<snapshot_name>.ldev.conf`.

## Usage

### Create a snapshot

```bash
lctl_snapshot_create.sh -F <fsname> -n <snapshot_name> [-c <comment>]
```

Creates the snapshot and saves a copy of the current `ldev.conf` for future mount/umount/destroy operations.

### List snapshots

```bash
lctl_snapshot_list.sh -F <fsname> [-n <snapshot_name>]
```

### Mount a snapshot

```bash
lctl_snapshot_mount.sh -F <fsname> -n <snapshot_name> [-l <ldev_conf_path>]
```

The `-l` option overrides the default snapshot ldev conf path (useful for snapshots created before this tooling was in place).

### Unmount a snapshot

```bash
lctl_snapshot_umount.sh -F <fsname> -n <snapshot_name> [-l <ldev_conf_path>]
```

### Destroy a snapshot

```bash
lctl_snapshot_destroy.sh -F <fsname> -n <snapshot_name> [-f]
```

The `-f` flag forces destruction. Also removes the snapshot's saved `ldev.conf`.

## SSH Command Validator

`lctl_ssh_command_validator.sh` restricts remote SSH access to only the allowed snapshot commands. Set it as a forced command in `authorized_keys`:

```
command="/usr/local/sbin/lctl_ssh_command_validator.sh" ssh-rsa AAAA... user@host
```

Allowed commands:
- `/etc/init.d/lustre status MGS`
- `lctl_snapshot_create.sh` (with any arguments)
- `lctl_snapshot_destroy.sh` (with any arguments)
- `lctl_snapshot_list.sh` (with any arguments)
- `lctl_snapshot_mount.sh` (with any arguments)
- `lctl_snapshot_umount.sh` (with any arguments)

Denied commands are logged to syslog at `auth.error` via `logger`.

## Configuration paths

| Path | Description |
|------|-------------|
| `/etc/ldev.conf` | Symlink managed by these scripts; points to live or snapshot config |
| `/etc/ldev/ldev.conf` | The live (active filesystem) ldev configuration |
| `/etc/ldev/<fsname>/<snapshot>.ldev.conf` | Per-snapshot ldev configuration |
