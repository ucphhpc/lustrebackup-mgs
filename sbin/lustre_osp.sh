#!/bin/bash
# -*- coding: utf-8 -*-
#
# --- BEGIN_HEADER ---
#
# lustre_osp - lustre Object Storage Proxy
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
#
# ------------------------------------------------------------
# Get Object Storage Proxy (OSP) values for for FS fsname-MDT
# -------------------------------------------------------------
# NOTE:
# The OSP (Object Storage Proxy) is the Lustre component
# that lets a metadata target (MDT) talk to other storage targets. 
# Each OSP device on a metadata server (MDS) stands in for one remote target,
# either an OST or, with DNE (multiple MDTs), another MDT. 
# The MDS can then treat that remote target much like local storage,
# while OSP turns the operations into network RPCs.
#
#          MDS
#  ┌───────────────────┐
#  │    MDT / MDD      │
#  │        │          │
#  │       LOD         │  decides striping and picks targets
#  │     ┌──┴───┐      │
#  │    OSD    OSP ────┼──► remote OST or MDT
#  └─────┼─────────────┘
#    local disk
# -------------------------------------------------

declare -r __scriptname__="$0"
declare __fsname__=""
declare __mdt__=""
declare __ostname__="OST*"
declare __key__="*"

usage () {
    # Usage help
    echo "Usage: $__scriptname__ [OPTIONS]" >&2
    echo "Where OPTIONS include:" >&2
    echo "-F        Lustre FS name" >&2
    echo "-M        Lustre MDT name" >&2
    echo "-O        Lustre OST name (optional)" >&2
    echo "-K        Lustre OSP key (optional)" >&2
}

parse_input() {
    # Parse command line options and arguments
    declare -i OPTIND
    # Parse commandline options
    while getopts hF:M:O:K: opt; do
        case "$opt" in
            h)      usage
                    exit 0;;
            F)      __fsname__=$OPTARG;;
            M)      __mdt__=$OPTARG;;
            O)      __ostname__=$OPTARG;;
            K)      __key__=$OPTARG;;
            \?)     # unknown flag
                    usage
                    exit 1;;
        esac
    done
    # Strip quotes
    __fsname__=${__fsname__//\"/}
    __fsname__=${__fsname__//\'/}
    __mdt__=${__mdt__//\"/}
    __mdt__=${__mdt__//\'/}
    __ostname__=${__ostname__//\"/}
    __ostname__=${__ostname__//\'/}
    __key__=${__key__//\"/}
    __key__=${__key__//\'/}
}


# ============================================================
# Main
# ============================================================
main() {
    parse_input "${@}"
    if [[ -z "$__fsname__" \
        || -z "$__mdt__" ]]; then
        usage
        return 1
    fi
    echo "$__scriptname__: fsname=${__fsname__} mdt=${__mdt__} ostname=${__ostname__} key=${__key__}" >&2

    cmd="lctl get_param 'osp.${__fsname__}-${__ostname__}-osc-${__mdt__}.${__key__}'"
    echo "$cmd" >&2
    eval "$cmd"
    ret=$?

    return $ret
}

# === Main ===
main "${@}"
exit $?
