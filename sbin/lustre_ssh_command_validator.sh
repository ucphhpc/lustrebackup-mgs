#!/bin/bash
# -*- coding: utf-8 -*-
#
# --- BEGIN_HEADER ---
#
# lustre_ssh_command_validator - lustre MGS ssh command validator
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

# Make sure only validated ssh commands are allowed
# NOTE: The remote rsync command must use '--protect-args'

SBIN_PATTERN="(/usr/sbin/|/sbin/|/usr/local/sbin/)"
MGS_STATUS_COMMAND="/etc/init.d/lustre status MGS"
SNAPSHOT_CREATE_PATTERN="${SBIN_PATTERN}?lctl_snapshot_create\.sh( .*)?"
SNAPSHOT_DESTROY_PATTERN="${SBIN_PATTERN}?lctl_snapshot_destroy\.sh( .*)?"
SNAPSHOT_LIST_PATTERN="${SBIN_PATTERN}?lctl_snapshot_list\.sh( .*)?"
SNAPSHOT_MOUNT_PATTERN="${SBIN_PATTERN}?lctl_snapshot_mount\.sh( .*)?"
SNAPSHOT_UMOUNT_PATTERN="${SBIN_PATTERN}?lctl_snapshot_umount\.sh( .*)?"
OBJ2ZFS_PATTERN="${SBIN_PATTERN}?lustre_obj2zfs\.sh( .*)?"
ZFS_SNAPSHOT_BLOCKS_PATTERN="${SBIN_PATTERN}?lustre_zfs_snapshot_blocks\.sh( .*)?"
ACTIVE_MDS_PATTERN="${SBIN_PATTERN}?lustre_active_mds\.sh( .*)?"
OSP_PATTERN="${SBIN_PATTERN}?lustre_osp\.sh( .*)?"
# echo "DEBUG: SSH_ORIGINAL_COMMAND: \"${SSH_ORIGINAL_COMMAND}\""

# NOTE: RSYNC_PATTERN regex MUST be unquoted here
if [[ "${SSH_ORIGINAL_COMMAND}" =~ ^${MGS_STATUS_COMMAND}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_CREATE_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_DESTROY_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_LIST_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_MOUNT_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_UMOUNT_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${OBJ2ZFS_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${ZFS_SNAPSHOT_BLOCKS_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${ACTIVE_MDS_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${OSP_PATTERN}$ ]]; then

    # /usr/bin/logger -t lctl_ssh_command_validator -p auth.info "Run restricted command: ${SSH_ORIGINAL_COMMAND}"
    eval "${SSH_ORIGINAL_COMMAND}"
else
    /usr/bin/logger -t lctl_ssh_command_validator -p auth.error "Refused illegal command: ${SSH_ORIGINAL_COMMAND}"
    exit 1
fi