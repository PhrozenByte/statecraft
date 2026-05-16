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

[ -e "$LIB_DIR/state-scripts/bind.sh" ] && source "$LIB_DIR/state-scripts/bind.sh" \
    || { echo "Missing dependency for 'external-drive.sh' state script: 'bind.sh' state script" >&2; exit 1; }

_check_external_drive_device() {
    [ -b "/dev/disk/by-label/$1" ]
}

_check_external_drive_mount() {
    local DRIVE_MOUNT="$(mountinfo_dev "/dev/disk/by-label/$1" "target" ||:)"
    [ -n "$DRIVE_MOUNT" ]
}

_poll_external_drive_device() {
    local DRIVE_LABEL="$1"
    local STATUS="$2"

    # check whether drive is plugged in; if not, return status 5 ("not plugged in")
    if ! _check_external_drive_device "$DRIVE_LABEL"; then
        if (( STATUS != 5 )); then
            (( STATUS == 0 )) || quiet ""
            quiet "External drive ${DRIVE_LABEL@Q} is not plugged in"
            quiet -n "Waiting for external drive to be plugged in"
        fi
        return 5
    fi

    # return status 4 ("plugged in") or better
    return $(( STATUS > 4 ? 4 : STATUS ))
}

_poll_external_drive_mount() {
    local DRIVE_LABEL="$1"
    local STATUS="$2"

    # no need to check for a mountpoint when drive isn't even plugged in
    ! (( STATUS > 4 )) || return $STATUS

    # check whether drive is mounted; if not, return status 3 ("not mounted")
    if ! _check_external_drive_mount "$DRIVE_LABEL"; then
        if (( STATUS != 3 )); then
            (( STATUS == 0 )) || quiet ""
            quiet "External drive ${DRIVE_LABEL@Q} is not mounted"
            quiet -n "Waiting for external drive to be mounted"
        fi
        return 3
    fi

    # return status 2 ("mounted") or better
    # if prior status was status 2, switch to status 1 ("ready")
    return $(( STATUS > 2 ? 2 : STATUS == 0 ? 0 : 1 ))
}

_wait_external_drive() {
    local DRIVE_LABEL="$1"
    local TIMEOUT="$2"

    # wait for the external drive to be mounted
    # use return codes to indicate the current status:
    #     0 = no-op / 1 = ready / 2 = mounted / 3 = not mounted /
    #     4 = plugged in / 5 = not plugged in
    local STATUS=0 i
    for (( i=1 ; i <= TIMEOUT; i++ )); do
        _poll_external_drive_device "$DRIVE_LABEL" "$STATUS" || STATUS=$?
        _poll_external_drive_mount "$DRIVE_LABEL" "$STATUS" || STATUS=$?

        # quit early if the drive is mounted from the start
        (( STATUS > 1 )) || break

        sleep 1
        quiet -n "."
    done

    # quit nicely if we had to wait
    if (( STATUS > 0 )); then
        quiet ""

        # we get here either by a timeout, or after the drive was mounted
        # in case of a timeout we want a proper error message, so check again
        # in case of a successfully mounted drive we still have trust issues, so check again
        if ! _check_external_drive_device "$DRIVE_LABEL"; then
            echo "Invalid path ${ID@Q}: External drive ${DRIVE_LABEL@Q} is not plugged in" >&2
            return 1
        elif ! _check_external_drive_mount "$DRIVE_LABEL"; then
            echo "Invalid path ${ID@Q}: External drive ${DRIVE_LABEL@Q} is not mounted" >&2
            return 1
        fi
    fi
}

_setup_external_drive() {
    local ID="$1"
    local TIMEOUT="${2:-60}"

    # the source path must match '/<external drive label>[/<relative path>]'
    # this neatly encodes the external drive's label into the path
    local MOUNT_SOURCE="$(unescape_source_path "$ID")"
    [[ "$MOUNT_SOURCE" =~ ^/([^/]+)(/.+)?$ ]] \
        || { echo "Invalid path ${ID@Q}: Malformed source path ${MOUNT_SOURCE@Q} for an external drive," \
            "expecting format '/<external drive label>[/<relative path>]'" >&2; return 1; }

    local DRIVE_LABEL="${BASH_REMATCH[1]}"
    local DRIVE_PATH="${BASH_REMATCH[2]}"

    # check whether the external drive is mounted and if it isn't, wait for up to $TIMEOUT seconds
    _wait_external_drive "$DRIVE_LABEL" "$TIMEOUT"

    # get the external drive's mount point
    local DRIVE_MOUNT="$(mountinfo_dev "/dev/disk/by-label/$DRIVE_LABEL" "target" ||:)"
    [ -n "$DRIVE_MOUNT" ] || { echo "Invalid path ${ID@Q}:" \
        "External drive ${DRIVE_LABEL@Q} is not ready" >&2; return 1; }

    quiet "External drive ${DRIVE_LABEL@Q} is mounted at ${DRIVE_MOUNT@Q}"

    # hand over the bind mount to the 'bind.sh' state script
    _setup_bind_mount "${ID%%+*}+$(escape_path "$DRIVE_MOUNT$DRIVE_PATH")"
}

setup_path() {
    _setup_external_drive "$@"
}
