# lustrebackup-mgs

Lustre snapshot backup Management Service (MGS) tools, and the MDS tools for the ZFS filediff of [lustrebackup](https://github.com/ucphhpc/lustrebackup).

Developed by the [Science HPC Center at UCPH](https://www.science.ku.dk/english/research/). Licensed under the [GNU General Public License v2](LICENSE).

## Overview

This project provides the scripts that lustrebackup runs over SSH on the Lustre MGS and MDS nodes:

- **Snapshot scripts (MGS):** bash wrapper scripts around Lustre's `lctl snapshot` commands. They solve a core limitation: Lustre cannot handle dynamic changes to `ldev.conf` between snapshot operations. These scripts atomically swap the `ldev.conf` symlink to the correct snapshot-specific configuration before each `lctl` call, then restore it afterwards — all protected by `flock` to prevent race conditions.
- **ZFS filediff scripts (MDS):** they find the ZFS object behind each OST object of a file and list that object's blocks in a snapshot, so lustrebackup only transfers the blocks that changed since the last backup.
- **SSH command validator:** a forced SSH command that only allows the scripts above.

## Requirements

- Lustre filesystem with `lctl` available
- An existing `/etc/ldev.conf`
- `bash`, `flock`, standard Unix utilities
- `logger` (for the SSH command validator)

For the ZFS filediff scripts:

- Lustre 2.15 or older: `lustre_obj2zfs.sh` only resolves IDIF OST objects (`O/0`), which MDT0000 creates before Lustre 2.16
- ZFS-backed OSTs, with `zfs` and `zdb` on the OSSs
- Root SSH from every MDS node to every OSS, including failover partners, on the IP address of the OST's current Lustre NID (for `o2ib`, the IPoIB address), with the OSS host keys in root's `known_hosts`

## Installation

Copy files to their respective system locations on every MGS and MDS node, including failover partners:

```bash
cp lib/lustre_snapshot_ldev_init.sh /usr/local/lib/
cp sbin/*.sh                        /usr/local/sbin/
```

The snapshot scripts load the library from `/usr/local/lib`. lustrebackup runs the scripts by name, so keep them in a directory on root's `PATH`.

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

### Read OSP parameters (MDS)

```bash
lustre_osp.sh -F <fsname> -M <mdt> [-O <ost>] [-K <key>]
```

Prints the output of `lctl get_param osp.<fsname>-<ost>-osc-<mdt>.<key>`. `<ost>` defaults to all OSTs (`OST*`) and `<key>` to all parameters (`*`). lustrebackup uses `-K active` to find the MDS that serves `<mdt>`, and `-O <ost> -K active` and `-O <ost> -K ost_conn_uuid` to check an OST before it uses its cached ZFS objects.

### Find the ZFS object of an OST object (MDS)

```bash
lustre_obj2zfs.sh -F <fsname> -M <mdt> -i <ost_index> -o <oid> [-S <snapshot_name>]
```

- `-i`: the OST index, `l_ost_idx` from `lfs getstripe --yaml`
- `-o`: the OST object id from `l_fid` (`f_seq:f_oid:f_ver`): `oid = (f_seq & 0xffff) << 32 | f_oid`
- `-S`: look the object up in this snapshot of the OST dataset

The script checks that the OST is active on this MDS, finds the OSS from the OST's current connection and the OST's ZFS dataset on that OSS, and then follows `O/0/d<oid % 32>/<oid>` with `zdb`. The result is printed as `key: value` lines, including `oss_ip`, `dataset` and `zfs_obj`.

### List the blocks of a ZFS object in a snapshot (MDS)

```bash
lustre_zfs_snapshot_blocks.sh <oss_ip>:<dataset>:<snapshot1>:<snapshot2>:<zfs_obj>
```

Prints the dataset's record size (`blocksize=`), the creation txg of `<snapshot1>` (`createtxg=`), and the `zdb -ddddd` output for `<zfs_obj>` in `<snapshot2>`. Blocks born after that txg changed between the two snapshots.

## SSH Command Validator

`lustre_ssh_command_validator.sh` restricts remote SSH access to only the allowed commands. Set it as a forced command in root's `authorized_keys` on every MGS and MDS node, replacing `HOST` and `HOST_IP` with the lustrebackup host that connects:

```
from="HOST,HOST_IP",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty,command="/usr/local/sbin/lustre_ssh_command_validator.sh" ssh-rsa AAAA... user@host
```

Allowed commands:
- `/etc/init.d/lustre status MGS`
- `lctl_snapshot_create.sh` (with any arguments)
- `lctl_snapshot_destroy.sh` (with any arguments)
- `lctl_snapshot_list.sh` (with any arguments)
- `lctl_snapshot_mount.sh` (with any arguments)
- `lctl_snapshot_umount.sh` (with any arguments)
- `lustre_osp.sh` (with any arguments)
- `lustre_obj2zfs.sh` (with any arguments)
- `lustre_zfs_snapshot_blocks.sh` (with any arguments)

The scripts may be called with or without a `/usr/sbin/`, `/sbin/` or `/usr/local/sbin/` prefix. Denied commands are logged to syslog at `auth.error` via `logger`.

## Upgrading

`lctl_ssh_command_validator.sh` has been renamed to `lustre_ssh_command_validator.sh`. Install the new scripts, point the forced command in `authorized_keys` to `/usr/local/sbin/lustre_ssh_command_validator.sh`, and remove `/usr/local/sbin/lctl_ssh_command_validator.sh`.

## Configuration paths

| Path | Description |
|------|-------------|
| `/etc/ldev.conf` | Symlink managed by these scripts; points to live or snapshot config |
| `/etc/ldev/ldev.conf` | The live (active filesystem) ldev configuration |
| `/etc/ldev/<fsname>/<snapshot>.ldev.conf` | Per-snapshot ldev configuration |
