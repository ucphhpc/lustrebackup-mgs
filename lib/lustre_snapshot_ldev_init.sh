#!/bin/bash
# -*- coding: utf-8 -*-
#
# --- BEGIN_HEADER ---
#
# lustre_snapshot_ldev_init - lustre MGS ldev init
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

declare -rx __ldev_home__="/etc/ldev"
declare -rx __ldev_conf_name__="ldev.conf"
declare -rx __ldev_conf_live__="$__ldev_home__/$__ldev_conf_name__"
declare -rx __ldev_conf__="/etc/$__ldev_conf_name__"

ldev_conf_init() {
    declare cmd=""
    declare ret=0
    
    # Check if ldev conf exists
    if [[ ! -e "$__ldev_conf__" ]]; then
        echo "Missing ldev conf: $__ldev_conf__" >&2
        return 1
    fi
    # Ensure snapshot ldev home
    cmd="mkdir -p \"$__ldev_home__\""
    # echo "$cmd" >2&
    eval "$cmd"
    ret=$?
    if [[ "$ret" -ne 0 ]]; then
        echo "Failed to ensure ldev home: $__ldev_home__" >&2
        return $ret
    fi
    # Check if __ldev_conf__ is a link and if not
    # then move to ldev home and create link
    if [[ ! -L "$__ldev_conf__" ]]; then
        if [[ ! -f "$__ldev_conf__" ]]; then
            echo "Neither link nor file: $__ldev_conf__ "
            return 1
        fi
        # If ldev conf live exists then backup it up
        if [[ -e "$__ldev_conf_live__" ]]; then
            timestamp=$(date +%s)
            cmd="mv \"$__ldev_conf_live__\" \"$__ldev_conf_live__.${timestamp}\""
            # echo "$cmd" >&2
            eval "$cmd"
            ret=$?
            if [[ "$ret" -ne 0 ]]; then
                echo "Failed to backup existing ldev conf: $__ldev_conf_live__" >&2
                return $ret
            fi
        fi
        # Move ldev conf to ldev home and create link
        cmd="flock -x \"$__ldev_conf__\" -c 'mv \"$__ldev_conf__\" \"$__ldev_conf_live__\""
        cmd="$cmd && ln -sf \"$__ldev_conf_live__\" \"$__ldev_conf__\"'"
        #echo "$cmd" >&2
        eval "$cmd"
        ret=$?
        if [[ "$ret" -ne 0 ]]; then
            echo "Failed to initialize ldev snapshot ldev" >&2
            return $ret
        fi
    fi

    return $ret
}
