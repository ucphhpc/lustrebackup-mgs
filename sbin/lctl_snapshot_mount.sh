#!/bin/bash
# -*- coding: utf-8 -*-
#
# --- BEGIN_HEADER ---
#
# lctl_snapshot_mount - lustre MGS snapshot mount
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
declare __opt_ldev_conf__=""

usage () {
    # Usage help
    echo "Usage: $__scriptname__ [OPTIONS]" >&2
    echo "Where OPTIONS include:" >&2
    echo "-F        fsname" >&2
    echo "-n        snapshot name" >&2
    echo "-l        snapshot ldev conf (optional)" >&2
}

parse_input() {
    # Parse command line options and arguments
    declare -i OPTIND
    # Parse commandline options
    while getopts hF:n:r:l: opt; do
        case "$opt" in
            h)      usage
                    exit 0;;
            F)      __fsname__=$OPTARG;;
            n)      __snapshot_name__=$OPTARG;;
            l)      __opt_ldev_conf__=$OPTARG;;
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
    __opt_ldev_conf__=${__opt_ldev_conf__//\"/}
    __opt_ldev_conf__=${__opt_ldev_conf__//\'/}
}

main() {
    # Main
    declare cmd=""
    parse_input "${@}"
    if [[ -n "$__opt_ldev_conf__" ]]; then
        declare -r snapshot_ldev_conf="$__opt_ldev_conf__"
    else
        declare -r snapshot_ldev_conf="$__ldev_home__/$__fsname__/$__snapshot_name__.ldev.conf"
    fi
    if [[ -z "$__fsname__" || -z "$__snapshot_name__" ]]; then
        usage
        return 1
    fi

    # Check if snapshot is already mounted 

    check_command="lctl snapshot_list --fsname \"${__fsname__}\" --name \"${__snapshot_name__}\" | grep -q \"status: mounted\""
    # echo "$check_command"
    eval "$check_command"
    ret=$?
    # echo "$ret"
    if [[ "$ret" -eq 0 ]]; then
        echo "$__fsname__ snapshot $__snapshot_name__ is already mounted" >&2
        return 0
    fi

    # Check of snapshot ldev conf exists
    
    if [[ ! -f "${snapshot_ldev_conf}" ]]; then
        echo "Missing snapshot ldev conf file: ${snapshot_ldev_conf}" >&2
        # return 1
        # TODO: Remove eventually
        # this should only happen for snapshots created before this ldev structure
        [[ -n "$__opt_ldev_conf__" ]] && return 1
        cmd="cp -L \"$__ldev_conf__\" \"${snapshot_ldev_conf}\""
        # echo "$cmd"
        eval "$cmd"
    fi

    # Try to mount snapshot 
    # NOTE: Not completely race-safe but 'flock' will ensure wait
    # in the case where other processes is holding a lock on ldev.conf
    cmd="flock -x \"$__ldev_conf__\" -c '"
    cmd="$cmd ln -sf \"${snapshot_ldev_conf}\" \"$__ldev_conf__\""
    cmd="$cmd && lctl snapshot_mount --fsname \"$__fsname__\""
    cmd="$cmd --name \"$__snapshot_name__\""
    cmd="$cmd ; ret_lctl=\$?"
    cmd="$cmd ; ln -sf \"$__ldev_conf_live__\" \"$__ldev_conf__\""
    cmd="$cmd ; ret_ln=\$?"
    cmd="$cmd ; [[ "\$ret_ln" -ne 0 ]] && exit \$ret_ln"
    cmd="$cmd ; exit \$ret_lctl'"
    # echo "$cmd" >2&
    eval "$cmd"
    ret=$?
    # If lctl failed then use lctl return code
    [[ "${ret_lctl}" -ne 0 ]] && ret=${ret_lctl}
    if [[ "$ret" -ne 0 ]]; then
        echo "Failed to mount $__fsname__ snapshot: $__snapshot_name__" >&2
    fi

    return $ret
}

# === Main ===
main "${@}"
exit $?
