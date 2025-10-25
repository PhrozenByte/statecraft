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

[ -x "$(type -p lvs)" ] || { echo "Missing dependency for 'lvm.sh' state script: lvs" >&2; exit 1; }
[ -x "$(type -p lvcreate)" ] || { echo "Missing dependency for 'lvm.sh' state script: lvcreate" >&2; exit 1; }

_lvm_info() {
    local DEVICE="$(mountinfo "$1" "source" | tail -n1)"
    [ -n "$DEVICE" ] || return 1

    local STATUS="$(lvs --noheadings --separator ' ' -o vg_name,lv_name,lv_path "$DEVICE" 2> /dev/null)"
    [ -n "$STATUS" ] && sed -e 's/^  *//g;s/  *$//g' <<< "$STATUS"
}

_lvm_device() {
    local VOLUME="$(lvs --noheadings --separator ' ' -o lv_path "$1" 2> /dev/null)"
    [ -n "$VOLUME" ] && sed -e 's/^  *//g;s/  *$//g' <<< "$VOLUME"
}

_lvm_mountpoint() {
    local ID="$1"
    local MOUNT="$(unescape_path "$ID")"

    check_path "$MOUNT" "Invalid path ${ID@Q}: Invalid LVM volume" -edrx
    mountpoint -q "$MOUNT" || { echo "Invalid path ${ID@Q}:" \
        "Invalid LVM volume ${MOUNT@Q}: Not a mount point" >&2; return 1; }
    [ -n "$(_lvm_info "$MOUNT")" ] || { echo "Invalid path ${ID@Q}:" \
        "Invalid LVM volume ${MOUNT@Q}: Backing block device is not a LVM logical volume" >&2; return 1; }

    echo "$MOUNT"
}

_lvm_snapshot_create() {
    local VOLUME="$1"
    local LVM_LV_SNAPSHOT="$2"
    local LVM_QUIET=
    [ -n "$VERBOSE" ] || LVM_QUIET="-qq"

    quiet "Create readonly LVM snapshot ${LVM_LV_SNAPSHOT@Q} of ${VOLUME@Q}"
    cmd lvcreate $LVM_QUIET --snapshot --permission r --extents 5%ORIGIN \
        --name "$LVM_LV_SNAPSHOT" "$VOLUME"
}

_lvm_snapshot_delete() {
    local SNAPSHOT="$1"
    local LVM_QUIET=
    [ -n "$VERBOSE" ] || LVM_QUIET="-qq"

    trap_exit lvremove $LVM_QUIET --force "$SNAPSHOT"
    trap_exit quiet "Delete LVM snapshot ${SNAPSHOT@Q}"
}

_lvm_snapshot_mount() {
    local SNAPSHOT="$1"
    local MOUNT="$2"

    quiet "Mount ${SNAPSHOT@Q} to ${MOUNT@Q}"
    cmd mount -o ro "$SNAPSHOT" "$TARGET_DIR$MOUNT"
}

_lvm_snapshot_umount() {
    local MOUNT="$1"

    trap_exit umount "$TARGET_DIR$MOUNT"
    trap_exit quiet "Unmount ${MOUNT@Q}"
}

_setup_lvm_mount() {
    local ID="$1"

    # get source mountpoint
    local MOUNT="$(_lvm_mountpoint "$ID")"
    [ -n "$MOUNT" ]

    # get LVM volume info
    local LVM_VG= LVM_LV= VOLUME=
    IFS=' ' read -r LVM_VG LVM_LV VOLUME < <(_lvm_info "$MOUNT")
    [ -n "$VOLUME" ] && [ -n "$LVM_VG" ] && [ -n "$LVM_LV" ]

    # create LVM snapshot
    _lvm_snapshot_create "$VOLUME" "${LVM_LV}+snap_$RUN_ID"

    local SNAPSHOT="$(_lvm_device "$LVM_VG/${LVM_LV}+snap_$RUN_ID")"
    _lvm_snapshot_delete "$SNAPSHOT"

    # create target mountpoint, if necessary
    mkmountpoint "$TARGET_DIR" "$ID"

    # mount snapshot
    _lvm_snapshot_mount "$SNAPSHOT" "$MOUNT"
    _lvm_snapshot_umount "$MOUNT"

    return 0
}

setup_path() {
    _setup_lvm_mount "$@"
}
