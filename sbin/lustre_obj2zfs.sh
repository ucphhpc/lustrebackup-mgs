#!/bin/bash
# -*- coding: utf-8 -*-
#
# --- BEGIN_HEADER ---
#
# lustre_obj2zfs - lustre object id to zfs object id
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

# Resolve zfs object id from lustre f_seq and f_oid
# f_seq and f_oid are obtained on the client using:
# 'lfs getstripe filepath'

declare -r __scriptname__="$0"
declare __fsname__=""
declare __mdt__=""
declare __snapname__=""
declare __ost_idx__=""
declare __f_oid__=""


usage () {
    # Usage help
    echo "Usage: $__scriptname__ [OPTIONS]" >&2
    echo "Where OPTIONS include:" >&2
    echo "-F        Lustre FS name" >&2
    echo "-M        Lustre MDT name" >&2
    echo "-S        Lustre snapshot name" >&2
    echo "-i        Lustre ost index (l_ost_idx)" >&2
    echo "          (lfs getstripe --yaml -> l_ost_idx)" >&2
    echo "-o        Lustre file oid (f_oid)" >&2
    echo "          (lfs getstripe --yaml -> l_fid ->  f_seq:f_oid:f_ver)" >&2
}

parse_input() {
    # Parse command line options and arguments
    declare -i OPTIND
    # Parse commandline options
    while getopts hF:M:S:i:o: opt; do
        case "$opt" in
            h)      usage
                    exit 0;;
            F)      __fsname__=$OPTARG;;
            M)      __mdt__=$OPTARG;;
            S)      __snapname__=$OPTARG;;
            i)      __ost_idx__=$OPTARG;;
            o)      __f_oid__=$OPTARG;;
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
    __snapname__=${__snapname__//\"/}
    __snapname__=${__snapname__//\'/}
    __ost_idx__=${__ost_idx__//\"/}
    __ost_idx__=${__ost_idx__//\'/}
    __f_oid__=${__f_oid__//\"/}
    __f_oid__=${__f_oid__//\'/}
}


# ============================================================
# Check if OST is active in the currendt MDS
# ============================================================
is_active_ost() {
    local fsname=$1
    local mdt=$2
    local ost_name=$3
    local res=0
    local active=""
    active=$(lctl get_param osp.${fsname}-${ost_name}-osc-${mdt}.active 2>/dev/null \
            | awk -F'active=' '{print $2}')
    res=$?
    if [[ "$res" -eq 0 && "$active" -eq 0 ]]; then
        res=1
    fi
    return $res
}

# ============================================================
# Resolve OSS IP from OST index using osp on MDS
# ============================================================
get_oss_ip() {
    local fsname=$1
    local mdt=$2
    local ost_name=$3

    lctl get_param osp.${__fsname__}-${ost_name}-osc-${mdt}.import \
        | grep current_connection \
        | awk '{print $2}' \
        | cut -d@ -f1 \
        | head -1
}

# ============================================================
# Resolve ZFS dataset from OSS and OST index using OSPx on MDS
# ============================================================
get_ost_dataset() {
    local oss_ipaddr=$1
    local fsname=$2
    local ost_name=$3

    ssh ${oss_ipaddr} \
        "lctl get_param osd-zfs.${fsname}-${ost_name}.mntdev \
        | awk -F'.mntdev=' '{print \$2}'"
}

# ============================================================
# FID -> ZFS object id resolver
# ============================================================
fid_to_zfs_obj() {
    local oss_ipaddr=$1
    local dataset=$2
    local fid_oid=$3
    local fid_oid_int=$(printf '%d' ${fid_oid})

    if [ -z "${fid_oid_int}" ] || [ -z "${dataset}" ]; then
        echo "fid_to_zfs_obj: error: uninitialized variable" >&2
        return 1
    fi

    # ZFS master node is always object 1 — contains filesystem-level metadata
    # including a pointer to the root directory object via the ROOT key
    local root_obj=$(ssh ${oss_ipaddr} \
        "zdb -dddd ${dataset} 1 | awk '/ROOT =/{print \$3}'")
    echo "root_obj: ${root_obj}"

    # The root directory object contains all top-level Lustre structures
    # created at mkfs time — CONFIGS, oi.* OI shards, O (object store),
    # LFSCK, seq_srv etc. We look up the "O" key to find the object store root
    local O_obj=$(ssh ${oss_ipaddr} \
        "zdb -dddd ${dataset} ${root_obj} | awk '/^\t\tO =/{print \$3}'")
    echo "O_obj: ${O_obj}"

    # The object store root contains one subdirectory per FID sequence group
    # IDIF sequences (OST data objects) always map to a directory named "0"
    # regardless of the actual sequence value or OST index
    local seq_obj=$(ssh ${oss_ipaddr} \
        "zdb -dddd ${dataset} ${O_obj} | awk '/^\t\t0 =/{print \$3}'")
    echo "seq_obj: ${seq_obj}"

    # The IDIF sequence directory contains OSD_OST_MAP_SIZE hash bucket
    # subdirectories named d0..d<OSD_OST_MAP_SIZE-1>
    # We count only the d* directories to derive the actual map size
    local map_size=$(ssh ${oss_ipaddr} \
        "zdb -dddd ${dataset} ${seq_obj} | grep -cP '^\t\td[0-9]+'")
    if [ -z "${map_size}" ] || [ "${map_size}" -eq 0 ]; then
        echo "fid_to_zfs_obj: error: could not determine map_size" >&2
        return 1
    fi
    echo "map_size: ${map_size}"

    # Hash the decimal object id into a bucket using modulo
    # mirrors osd_get_idx_for_ost_obj() in osd-zfs/osd_oi.c:
    # b = id % OSD_OST_MAP_SIZE
    local bucket=$((fid_oid_int % map_size))
    echo "bucket: ${bucket}"

    # Look up the bucket directory object number from the sequence directory
    # Each bucket directory is a ZAP named d<bucket> containing the
    # object id to ZFS dnode mappings for all objects in that bucket
    local d_obj=$(ssh ${oss_ipaddr} \
        "zdb -dddd ${dataset} ${seq_obj} | awk '/^\t\td${bucket} =/{print \$3}'")
    echo "d_obj: ${d_obj}"

    # Look up the decimal object id in the bucket directory ZAP
    # The value is the actual ZFS dnode object number which can be
    # passed to zdb -ddddd to inspect block pointers and birth txg values
    local zfs_obj=$(ssh ${oss_ipaddr} \
        "zdb -dddd ${dataset} ${d_obj} | awk '/^\t\t${fid_oid_int} =/{print \$3}'")
    echo "zfs_obj: ${zfs_obj}"
}

# ============================================================
# Main
# ============================================================
main() {
    local rc=0
    parse_input "${@}"
    if [[ -z "$__fsname__" \
        || -z "$__mdt__" \
        || -z "$__ost_idx__" \
        || -z "$__f_oid__" ]]; then
        usage
        return 1
    fi
    echo "$__scriptname__: fsname=${__fsname__} mdt=${__mdt__} ost_idx=${__ost_idx__} oid=${__f_oid__}" >&2

    # Derive OST hex index and name from OST index
    ost_idx_hex=$(printf '%04x' "${__ost_idx__}")
    echo "ost_idx_hex: ${ost_idx_hex}"
    ost_name="OST${ost_idx_hex}"
    echo "ost_name: ${ost_name}"

    # Check that OST is active on this MDS
    is_active_ost ${__fsname__} ${__mdt__} ${ost_name}
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo -n "No active OST with index ${ost_idx_hex}" >&2
        echo " found for ${__fsname__}-${__mdt__}" >&2
        return 1
    fi

    # Resolve OSS IP from osp on MDS
    oss_ip=$(get_oss_ip ${__fsname__} ${__mdt__} ${ost_name})
    if [ -z "${oss_ip}" ]; then
        echo "Failed to resolve oss_ip for OST with index ${ost_idx_hex}" >&2
        echo " found for ${__fsname__}-${__mdt__}" >&2
        return 1
    fi
    echo "oss_ip: ${oss_ip}"

    # Resolve ZFS dataset on OSS via osp on MDS
    dataset=$(get_ost_dataset ${oss_ip} ${__fsname__} ${ost_name})
    if [ -z "${dataset}" ]; then
        echo -n "Failed to resolve dataset from oss_ip: ${oss_ip}" >&2
        echo " for OST with index ${ost_idx_hex} for ${__fsname__}-${__mdt__}" >&2
        return 1
    fi

    # If snapshot name is given apply to dataset
    if [ -n "$__snapname__" ]; then
        dataset="${dataset}@${__snapname__}"
    fi
    echo "dataset: ${dataset}"

    # Resolve ZFS object id from FID
    t1=$(date +%s%N)
    fid_to_zfs_obj ${oss_ip} ${dataset} ${__f_oid__}
    t2=$(date +%s%N)
    echo "fid_to_zfs_obj: $(((t2-t1)/1000000)) ms" >&2

    return $rc
}

# === Main ===
main "${@}"
exit $?
