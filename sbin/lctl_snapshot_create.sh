#!/bin/bash
# -*- coding: utf-8 -*-
#
# --- BEGIN_HEADER ---
#
# lctl_snapshot_create - lustre MGS snapshot create
# Copyright (C) 2020-2024  The lustrebackup-mgs Project by the Science HPC Center at UCPH
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
#

# Setup ldev snapshot directory configuration
# NOTE: lustre currently can't handle ldev changes
# between snapshots, therefore we handle them manually
source /usr/local/lib/lustre_snapshot_ldev_init.sh
ldev_conf_init
ret=$?
[[ "$ret" -ne 0 ]] && exit $ret

declare -r __scriptname__="$0"
declare __fsname__=""
declare __snapshot_name__=""
declare __comment__=""

usage () {
    # Usage help
    echo "Usage: $__scriptname__ [OPTIONS]" >&2
    echo "Where OPTIONS include:" >&2
    echo "-F        fsname" >&2 
    echo "-n        snapshot name" >&2
    echo "-c        snapshot comment" >&2
}

parse_input() {
    # Parse command line options and arguments
    declare -i OPTIND
    # Parse commandline options
    while getopts hF:n:c: opt; do
        case "$opt" in
            h)      usage
                    exit 0;;
            F)      __fsname__=$OPTARG;;
            n)      __snapshot_name__=$OPTARG;;
            c)      __snapshot_comment__=$OPTARG;;
            \?)     # unknown flag
                    usage
                    exit 1;;
        esac
    done
    # Strip quotes
    __fsname__=${__fsname__//\"/}
    __fsname__=${__fsname__//\'/}
    __snapshot_name__=${__snapshot_name__//\"/}
    __snapshot_name__=${__snapshot_name__//\'/}
    __snapshot_comment__=${__snapshot_comment__//\"/}
    __snapshot_comment__=${__snapshot_comment__//\'/}
}

main() {
    # Main
    declare cmd=""
    parse_input "${@}"
    declare -r __ldev_fshome__="$__ldev_home__/$__fsname__"    
    if [[ -z "$__fsname__" || -z "$__snapshot_name__" ]]; then
        usage
        return 1
    fi
    # Create snapshot
    # NOTE: Not completely race-safe but 'flock' will ensure wait
    # in the case where other processes is holding a lock on ldev.conf
    cmd="flock -x \"$__ldev_conf__\" -c 'exit 0'"
    cmd="$cmd && lctl snapshot_create --fsname \"$__fsname__\""
    cmd="$cmd --name \"$__snapshot_name__\""
    if [[ -n "$__snapshot_comment__" ]]; then
        cmd="$cmd --comment \"$__snapshot_comment__\""
    fi
    cmd="$cmd && mkdir -p \"$__ldev_fshome__\""
    cmd="$cmd && cp -L \"$__ldev_conf__\" \"$__ldev_fshome__/$__snapshot_name__.ldev.conf\""
    # echo "$cmd" >&2
    eval "$cmd"
    ret=$?
    # echo "$cmd" >&2
    if [ "$ret" -ne 0 ]; then
        echo "$__fsname__ failed to create snapshot $__snapshot_name__" >&2
    fi
   
    return $ret
}

# === Main ===
main "${@}"
exit $?
