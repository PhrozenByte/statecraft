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

[ -x "$(type -p btrfs)" ] || { echo "Missing dependency for 'btrfs.sh' state script: btrfs" >&2; exit 1; }

_is_btrfs_mount() {
    [ "$(mountinfo "$1" "fstype" | tail -n1)" == "btrfs" ]
}

_btrfs_subvolume() {
    local STATUS="$(btrfs subvolume show "$1" 2> /dev/null)"
    [ -n "$STATUS" ] && head -n1 - <<< "$STATUS"
}

_btrfs_sources() {
    local STATUS="$(btrfs filesystem show "$1" 2> /dev/null)"
    [ -n "$STATUS" ]

    local AWK_PROGRAM='$1 == "devid" { for (i=1; i<=NF; i++) { if ($i == "path") { print $(i+1) } } }'
    local DEVICES="$(awk "$AWK_PROGRAM" <<< "$STATUS")"
    [ -n "$DEVICES" ] && echo "$DEVICES"
}

_btrfs_source() {
    local DEVICE= DEVICE_ID=
    for DEVICE in "$@"; do
        DEVICE_ID="$(escape_path "$DEVICE")"
        [ ! -e "$RUN_DIR/$DEVICE_ID" ] || { echo "$DEVICE"; return 0; }
    done
    echo "$1"
}

_btrfs_mountpoint() {
    local ID="$1"
    local MOUNT="$(unescape_path "$ID")"

    check_path "$MOUNT" "Invalid path ${ID@Q}: Invalid btrfs subvolume" -edrx
    is_mountpoint "$MOUNT" || { echo "Invalid path ${ID@Q}:" \
        "Invalid btrfs subvolume ${MOUNT@Q}: Not a mount point" >&2; return 1; }
    _is_btrfs_mount "$MOUNT" || { echo "Invalid path ${ID@Q}:" \
        "Invalid btrfs subvolume ${MOUNT@Q}: Not a mount point of a btrfs filesystem" >&2; return 1; }

    echo "$MOUNT"
}

_btrfs_snapshot_create() {
    local SUBVOLUME_PATH="$1"
    local SNAPSHOT_PATH="$2"
    local BTRFS_QUIET=
    [ -n "$VERBOSE" ] || BTRFS_QUIET="-q"

    quiet "Create readonly btrfs snapshot of ${SUBVOLUME_PATH@Q} in ${SNAPSHOT_PATH@Q}"
    cmd btrfs $BTRFS_QUIET subvolume snapshot -r "$SUBVOLUME_PATH" "$SNAPSHOT_PATH"
}

_btrfs_snapshot_delete() {
    local SNAPSHOT_PATH="$1"
    local BTRFS_QUIET=
    [ -n "$VERBOSE" ] || BTRFS_QUIET="-q"

    trap_exit btrfs $BTRFS_QUIET subvolume delete "$SNAPSHOT_PATH"
    trap_exit quiet "Delete btrfs snapshot ${SNAPSHOT_PATH@Q}"
}

_btrfs_mount() {
    local MOUNT_OPTS=()
    while [ $# -ge 2 ]; do
        [ "$1" == "-o" ] \
            && { MOUNT_OPTS+=( "$2" ); shift 2; } \
            || break
    done

    local MOUNT="$1"
    MOUNT_OPTS+=( subvol="$2" )
    local DEVICE="$3"
    shift 3

    if [ $# -gt 1 ]; then
        while [ $# -gt 0 ]; do
            MOUNT_OPTS+=( device="$1" )
            shift
        done
    elif [ "$1" != "$DEVICE" ]; then
        return 1
    fi

    cmd mount -o "$(IFS=','; echo "${MOUNT_OPTS[*]}")" "$DEVICE" "$MOUNT"
}

_setup_btrfs_mount() {
    local ID="$1"

    # get source mountpoint
    local MOUNT="$(_btrfs_mountpoint "$ID")"
    [ -n "$MOUNT" ]

    # get source subvolume
    local SUBVOLUME="$(_btrfs_subvolume "$MOUNT")"
    [ -n "$SUBVOLUME" ] || { echo "Invalid path ${ID@Q}:" \
        "Invalid btrfs subvolume ${MOUNT@Q}: Not a mount point of a btrfs subvolume" >&2; return 1; }

    # get backing devices
    # we strictly use the same backing devices and don't rely on btrfs' auto-detection
    local DEVICES=(); readarray -t DEVICES < <(_btrfs_sources "$MOUNT")
    [ "${#DEVICES[@]}" -gt 0 ] || { echo "Invalid path ${ID@Q}:" \
        "Invalid btrfs subvolume ${MOUNT@Q}: Unable to determine backing block devices" >&2; return 1; }

    # identify primary backing device
    # either the first listed, or an already mounted backing device
    local DEVICE="$(_btrfs_source "${DEVICES[@]}")"
    local DEVICE_ID="$(escape_path "$DEVICE")"
    [ -n "$DEVICE" ] && [ -n "$DEVICE_ID" ]

    # check whether root subvolume is already mounted
    local ROOT_MOUNT="$RUN_DIR/$DEVICE_ID"
    if [ ! -e "$ROOT_MOUNT" ]; then
        quiet "Mount root subvolume of btrfs subvolume ${MOUNT@Q} to ${ROOT_MOUNT@Q}"

        # create mountpoint
        cmd mkdir -m 0700 "$ROOT_MOUNT"
        trap_exit rmdir "$ROOT_MOUNT"

        # mount root subvolume
        _btrfs_mount "$ROOT_MOUNT" "/" "$DEVICE" "${DEVICES[@]}"

        trap_exit umount "$ROOT_MOUNT"
        trap_exit quiet "Unmount ${ROOT_MOUNT@Q}"
    else
        quiet "Use mounted root subvolume of btrfs subvolume ${MOUNT@Q} at ${ROOT_MOUNT@Q}"

        # check whether mountpoint is valid
        local ROOT_MOUNT_INVALID="Invalid runtime directory ${RUN_DIR@Q}: Invalid mount point of btrfs root subvolume"
        check_path "$ROOT_MOUNT" "$ROOT_MOUNT_INVALID" -d
        is_mountpoint "$ROOT_MOUNT" \
            || { echo "$ROOT_MOUNT_INVALID ${ROOT_MOUNT@Q}: Not a mount point" >&2; return 1; }
        _is_btrfs_mount "$ROOT_MOUNT" \
            || { echo "$ROOT_MOUNT_INVALID ${ROOT_MOUNT@Q}: Not a mount point of a btrfs filesystem" >&2; return 1; }
        [ "$(_btrfs_subvolume "$ROOT_MOUNT")" == "/" ] \
            || { echo "$ROOT_MOUNT_INVALID ${ROOT_MOUNT@Q}: Not the btrfs root subvolume" >&2; return 1; }
        [ "$(_btrfs_sources "$ROOT_MOUNT" | sort)" == "$(printf '%s\n' "${DEVICES[@]}" | sort)" ] \
            || { echo "$ROOT_MOUNT_INVALID ${ROOT_MOUNT@Q}: Unexpected backing block devices" >&2; return 1; }
    fi

    # check whether root subvolume matches one of the two expected subvolume layouts
    local SUBVOLUME_PATH=
    local SUBVOLUME_PATH_INVALID="Invalid path ${ID@Q}: Invalid btrfs subvolume ${MOUNT@Q}"
    if [ "$SUBVOLUME" == "/" ]; then
        # btrfs filesystem consists of a single subvolume
        check_path "$ROOT_MOUNT" "$SUBVOLUME_PATH_INVALID: Invalid root subvolume mounted at" -rx

        SUBVOLUME_PATH="$ROOT_MOUNT"
        SUBVOLUME_PATH_INVALID="$SUBVOLUME_PATH_INVALID: Invalid '/.snapshots' directory in root subvolume mounted at"

        check_path "$SUBVOLUME_PATH/.snapshots" "$SUBVOLUME_PATH_INVALID" -edwx
    else
        # btrfs filesystem uses Snapper's subvolume layout
        check_path "$ROOT_MOUNT" "$SUBVOLUME_PATH_INVALID: Invalid root subvolume mounted at" -wx

        SUBVOLUME_PATH="$ROOT_MOUNT/$SUBVOLUME"
        SUBVOLUME_PATH_INVALID="$SUBVOLUME_PATH_INVALID: Invalid subvolume ${SUBVOLUME@Q} mounted at"

        [ "${SUBVOLUME:0:1}" == "@" ] || { echo "$SUBVOLUME_PATH_INVALID ${SUBVOLUME_PATH@Q}:" \
            "Subvolume doesn't match Snapper's subvolume layout" >&2; return 1; }
        check_path "$SUBVOLUME_PATH" "$SUBVOLUME_PATH_INVALID" -edrx
    fi

    # create target mountpoint, if necessary
    mkmountpoint "$TARGET_DIR" "$ID"

    # create snapshot
    local SNAPSHOT= SNAPSHOT_PATH=
    if [ "$SUBVOLUME" == "/" ]; then
        SNAPSHOT="/.snapshots/snap-$RUN_ID"
        SNAPSHOT_PATH="$ROOT_MOUNT$SNAPSHOT"
    else
        SNAPSHOT="/${SUBVOLUME}_snap-$RUN_ID"
        SNAPSHOT_PATH="$ROOT_MOUNT$SNAPSHOT"
    fi

    _btrfs_snapshot_create "$SUBVOLUME_PATH" "$SNAPSHOT_PATH"
    _btrfs_snapshot_delete "$SNAPSHOT_PATH"

    # mount snapshot
    quiet "Mount ${SNAPSHOT_PATH@Q} to ${MOUNT@Q}"
    _btrfs_mount -o ro "$TARGET_DIR$MOUNT" "$SNAPSHOT" "$DEVICE" "${DEVICES[@]}"

    trap_exit umount "$TARGET_DIR$MOUNT"
    trap_exit quiet "Unmount ${MOUNT@Q}"
    return 0
}

setup_path() {
    _setup_btrfs_mount "$@"
}
