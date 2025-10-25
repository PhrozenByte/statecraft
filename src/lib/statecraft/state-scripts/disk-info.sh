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

[ -x "$(type -p jq)" ] || { echo "Missing dependency for 'disk-info.sh' state script: jq" >&2; exit 1; }
[ -x "$(type -p lsblk)" ] || { echo "Missing dependency for 'disk-info.sh' state script: lsblk" >&2; exit 1; }
[ -x "$(type -p findmnt)" ] || { echo "Missing dependency for 'disk-info.sh' state script: findmnt" >&2; exit 1; }

_disk_info() {
    local DISKS=()

    local ID= MOUNT= DISK= DISK_META= FS_META= MOUNT_META=
    for ID in "${PATHS[@]}"; do
        MOUNT="$(unescape_path "$ID")"

        # skip paths that are no mount points (e.g. the 'disk-info.sh' state script)
        DISK="$(mountinfo "$MOUNT" source ||:)"
        [ -n "$DISK" ] || continue

        DISK_META="$(cmd lsblk --json --bytes --nodeps -o PATH,SIZE,PARTUUID,PARTTYPE,PARTLABEL "$DISK")"
        FS_META="$(cmd findmnt --json --bytes -o FSTYPE,SIZE,USED,UUID,LABEL "$DISK")"
        MOUNT_META="$(cmd findmnt --json -o TARGET,OPTIONS "$MOUNT")"

        DISKS+=( "$(jq -ne \
            --argjson partition "$(jq '.blockdevices[0]' <<< "$DISK_META")" \
            --argjson filesystem "$(jq '.filesystems[0]' <<< "$FS_META")" \
            --argjson mountpoint "$(jq '.filesystems[0]' <<< "$MOUNT_META")" \
            '$ARGS.named')" )
    done

    jq -s <<< "${DISKS[@]}"
}

_setup_disk_info_file() {
    local ID="$1"

    # create status file
    local FILENAME="$(unescape_path "$ID")"
    check_path "$TARGET_DIR$FILENAME" "Invalid path ${ID@Q}: Invalid disk information file" +e

    quiet "Write disk information to ${FILENAME@Q}"
    mkmountpoint "$TARGET_DIR" "$ID" "$(dirname "$FILENAME")"
    _disk_info > "$TARGET_DIR$FILENAME"

    # delete status file
    trap_exit rm "$TARGET_DIR$FILENAME"
    trap_exit quiet "Delete ${FILENAME@Q}"

    return 0
}

setup_path() {
    _setup_disk_info_file "$@"
}
