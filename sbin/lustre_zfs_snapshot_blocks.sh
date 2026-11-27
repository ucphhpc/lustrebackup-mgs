#!/bin/bash
# -*- coding: utf-8 -*-
#
# --- BEGIN_HEADER ---
#
# lustre_snapshot_blockdiff - lustre snapshot file block diff
# Copyright (C) 2020-2026  The lustrebackup-mgs Project by the Science HPC Center at UCPH
#
# This file is part of lustrebackup-mgs.
#
# lustrebackup-mgs is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# lustrebackup-mgs is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# -- END_HEADER ---

# Run on the MDS

declare -r __scriptname__="$0"

main() {
    local input=$1
    local ret=1
    if [ -z "${input}" ]; then
        echo "USAGE: $__scriptname__ oss_ip:dataset:snapshot1:snapshot2:zfs_obj" >&2
        return 1
    fi
    if IFS=: read oss_ip dataset snapshot1 snapshot2 zfs_obj <<< ${input}; then
        echo "$__scriptname__: oss_ip=${oss_ip} dataset=${dataset} snapshot1=${snapshot1} snapshot2=${snapshot2} zfs_obj=${zfs_obj}" >&2

        # Retrieve ZFS block size
        ssh ${oss_ip} "zfs get -Hp recordsize ${dataset} | awk '{print\"blocksize=\"\$3}'"
        ret=$?
        [ "$ret" -ne 0 ] && return $ret

        # Retrieve snapshot1 ZFS createtxg
        # NOTE: Blocks born after snapshot1 createtxg are new in snapshot2
        ssh ${oss_ip} \
                "zfs get -Hp createtxg ${dataset}@${snapshot1} | awk '{print \"createtxg=\"\$3}'"
        ret=$?
        [ "$ret" -ne 0 ] && return $ret

        # Retrieve ZFS object block pointer table for snapshot2
        ssh ${oss_ip} \
                "zdb -ddddd ${dataset}@${snapshot2} ${zfs_obj}"
        ret=$?
    fi
    return $ret
}

# === Main ===
main "${@}"
exit $?
