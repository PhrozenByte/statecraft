# StateCraft
# A CLI tool to create complex directory structures via scripts on Linux.
#
# StateCraft is a CLI tool for creating Linux directory trees via scripts.
# It supports mounting snapshots, creating files, archives, and more.
# Designed for admins seeking flexible, scriptable backup setups.
#
# Copyright (C) 2025  Daniel Rudolf <https://www.daniel-rudolf.de>
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

_bind_mountpoint() {
    local ID="$1"
    local MOUNT="$(unescape_path "$ID")"

    check_path "$MOUNT" "Invalid path ${ID@Q}: Invalid bind mount source path" -edrx

    echo "$MOUNT"
}

_bind_mount() {
    local MOUNT="$1"

    quiet "Bind mount ${MOUNT@Q}"
    cmd mount -o bind,ro "$MOUNT" "$TARGET_DIR$MOUNT"
}

_bind_umount() {
    local MOUNT="$1"

    trap_exit umount "$TARGET_DIR$MOUNT"
    trap_exit quiet "Unmount ${MOUNT@Q}"
}

_setup_bind_mount() {
    local ID="$1"

    local MOUNT="$(_bind_mountpoint "$ID")"
    [ -n "$MOUNT" ]

    # create target mountpoint, if necessary
    mkmountpoint "$TARGET_DIR" "$ID"

    # bind mount the directory
    _bind_mount "$MOUNT"
    _bind_umount "$MOUNT"

    return 0
}

setup_path() {
    _setup_bind_mount "$@"
}
