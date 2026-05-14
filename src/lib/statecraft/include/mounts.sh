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

is_mountpoint() {
    mountpoint -q "$1"
}

mountinfo() {
    local MOUNT="$1"
    local FIELD="${2,,}"

    is_mountpoint "$MOUNT"

    MOUNT="$(realpath "$MOUNT" 2> /dev/null ||:)"
    [ -n "$MOUNT" ]

    [ "$FIELD" != "target" ] || { echo "$MOUNT"; return 0; }

    local PROG=
    case "$FIELD" in
        "maj:min") PROG='$5 == m { print $3 }' ;;
        "fsroot")  PROG='$5 == m { print $4 }' ;;
        "fstype")  PROG='$5 == m { for (i=1; i <= NF; i++) { if ($i == "-") { print $(i+1); next } } }' ;;
        "source")  PROG='$5 == m { for (i=1; i <= NF; i++) { if ($i == "-") { print $(i+2); next } } }' ;;
        "options") PROG='$5 == m { for (i=1; i <= NF; i++) { if ($i == "-") { print $6 "," $(i+3); next } } }' ;;
        *)         echo "Failed to read mount info of ${MOUNT@Q}: Unknown field ${FIELD@Q}" >&2; return 1 ;;
    esac

    local RESULT="$(awk -v m="$MOUNT" "$PROG" /proc/self/mountinfo)"
    [ -n "$RESULT" ] && printf '%b\n' "$RESULT"
}

mkmountpoint() {
    local BASE_DIR="$1"
    local ID="$2"
    local MOUNT_TARGET="$(unescape_target_path "$ID")"
    local DIR="${3:-$MOUNT_TARGET}"

    if [ ! -e "$BASE_DIR$DIR" ]; then
        local SUBDIR_SRC= SUBDIR_SRC_STRIP=
        if [ -z "${3:-}" ]; then
            local MOUNT_SOURCE="$(unescape_source_path "$ID")"

            # strip '/foo/bar' from $SUBDIR_SRC from $MOUNT_TARGET with '/foo/bar/some/path+/some/path' IDs
            # this makes source and target path match again, allowing for `chmod`, `chown`, `chcon` below
            local STRIP_PATH="$MOUNT_TARGET"
            [[ "$MOUNT_TARGET" != *"$MOUNT_SOURCE" ]] \
                || STRIP_PATH="${MOUNT_TARGET:0:-${#MOUNT_SOURCE}}"
            STRIP_PATH="${STRIP_PATH//[^\/]/}"
            SUBDIR_SRC_STRIP=${#STRIP_PATH}
        fi

        local SUBDIR= SUBDIR_ABS= SUBDIR_DST=
        while IFS= read -u 3 -d '/' -r SUBDIR; do
            SUBDIR_ABS+="/$SUBDIR"
            SUBDIR_DST="$BASE_DIR$SUBDIR_ABS"

            [ -z "$SUBDIR_SRC_STRIP" ] \
                || { (( SUBDIR_SRC_STRIP > 0 )) && ((SUBDIR_SRC_STRIP--)); } \
                    || SUBDIR_SRC+="/$SUBDIR"

            if [ ! -e "$SUBDIR_DST" ]; then
                check_path "$(dirname "$SUBDIR_DST")" \
                    "Invalid path ${ID@Q}: Unable to create ${MOUNT_TARGET@Q} below" -dwx

                cmd mkdir "$SUBDIR_DST"
                trap_exit rmdir "$SUBDIR_DST"

                if [ -n "$SUBDIR_SRC" ]; then
                    cmd chmod "$(stat -c '%a' -L "$SUBDIR_SRC")" "$SUBDIR_DST"
                    cmd chown "$(stat -c '%u:%g' -L "$SUBDIR_SRC")" "$SUBDIR_DST"
                    [ -z "$SELINUX" ] || cmd chcon "$(stat -c '%C' -L "$SUBDIR_SRC")" "$SUBDIR_DST"
                fi
            else
                check_path "$SUBDIR_DST" "Invalid path ${ID@Q}: Unable to create ${MOUNT_TARGET@Q} below" -d
            fi
        done 3< <(printf '%s' "${DIR#/}/")
    else
        check_path "$BASE_DIR$DIR" "Invalid path ${ID@Q}: Unable to create ${MOUNT_TARGET@Q} at" -d
    fi
}
