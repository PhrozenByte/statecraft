# StateCraft
# A CLI tool to create complex directory structures via scripts on Linux.
#
# StateCraft is a CLI tool for creating Linux directory trees via scripts.
# It supports mounting snapshots, creating files, archives, and more.
# Designed for admins seeking flexible, scriptable backup setups.
#
# Copyright (C) 2025-2026  Daniel Rudolf <https://www.daniel-rudolf.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License only.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# License: GNU General Public License <https://opensource.org/license/gpl-3-0>
# SPDX-License-Identifier: GPL-3.0-only

_bind_mount() {
    local MOUNT_SOURCE="$1"
    local MOUNT_TARGET="${2:-$1}"

    [ "$MOUNT_SOURCE" == "$MOUNT_TARGET" ] \
        && quiet "Bind mount ${MOUNT_TARGET@Q}" \
        || quiet "Bind mount ${MOUNT_SOURCE@Q} to ${MOUNT_TARGET@Q}"
    cmd mount -o bind,ro "$MOUNT_SOURCE" "$TARGET_DIR$MOUNT_TARGET"
}

_bind_umount() {
    local MOUNT="$1"

    trap_exit umount "$TARGET_DIR$MOUNT"
    trap_exit quiet "Unmount ${MOUNT@Q}"
}

_setup_bind_mount() {
    local ID="$1"

    local MOUNT_SOURCE="$(unescape_source_path "$ID")"
    local MOUNT_TARGET="$(unescape_target_path "$ID")"

    # check source mountpoint
    check_path "$MOUNT_SOURCE" "Invalid path ${ID@Q}: Invalid bind mount source path" -edrx

    # create target mountpoint, if necessary
    mkmountpoint "$TARGET_DIR" "$ID"

    # bind mount the directory
    _bind_mount "$MOUNT_SOURCE" "$MOUNT_TARGET"
    _bind_umount "$MOUNT_TARGET"

    return 0
}

setup_path() {
    _setup_bind_mount "$@"
}
