#!/bin/bash
# -*- coding: utf-8 -*-
#
# --- BEGIN_HEADER ---
#
# lctl_ssh_command_validator - lustre MGS ssh command validator
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

# Make sure only validated ssh commands are allowed
# NOTE: The remote rsync command must use '--protect-args'

BIN_PATTERN="(/usr/bin/|/bin/|/usr/local/bin/)"
MGS_STATUS_COMMAND="/etc/init.d/lustre status MGS"
SNAPSHOT_CREATE_PATTERN="${BIN_PATTERN}?lctl_snapshot_create\.sh( .*)?"
SNAPSHOT_DESTROY_PATTERN="${BIN_PATTERN}?lctl_snapshot_destroy\.sh( .*)?"
SNAPSHOT_LIST_PATTERN="${BIN_PATTERN}?lctl_snapshot_list\.sh( .*)?"
SNAPSHOT_MOUNT_PATTERN="${BIN_PATTERN}?lctl_snapshot_mount\.sh( .*)?"
SNAPSHOT_UMOUNT_PATTERN="${BIN_PATTERN}?lctl_snapshot_umount\.sh( .*)?"

# echo "DEBUG: SSH_ORIGINAL_COMMAND: \"${SSH_ORIGINAL_COMMAND}\""

# NOTE: RSYNC_PATTERN regex MUST be unquoted here
if [[ "${SSH_ORIGINAL_COMMAND}" =~ ^${MGS_STATUS_COMMAND}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_CREATE_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_DESTROY_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_LIST_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_MOUNT_PATTERN}$ \
        || "${SSH_ORIGINAL_COMMAND}" =~ ^${SNAPSHOT_UMOUNT_PATTERN}$ ]]; then

    # /usr/bin/logger -t lctl_ssh_command_validator -p auth.info "Run restricted command: ${SSH_ORIGINAL_COMMAND}"
    eval "${SSH_ORIGINAL_COMMAND}"
else
    /usr/bin/logger -t lctl_ssh_command_validator -p auth.error "Refused illegal command: ${SSH_ORIGINAL_COMMAND}"
    exit 1
fi