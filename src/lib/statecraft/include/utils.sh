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

quote() {
    local QUOTED=
    for ARG in "$@"; do
        [ "$(printf '%q' "$ARG")" == "$ARG" ] \
            && QUOTED+=" $ARG" \
            || QUOTED+=" ${ARG@Q}"
    done
    echo "${QUOTED:1}"
}

verbose() {
    if [ -n "$VERBOSE" ]; then
        [ $# -eq 0 ] || { echo "$@" >&2; return 0; }
        cat >&2
    elif [ $# -eq 0 ]; then
        cat > /dev/null
    fi
}

quiet() {
    if [ -z "$QUIET" ]; then
        [ $# -eq 0 ] || { echo "$@"; return 0; }
        cat
    elif [ $# -eq 0 ]; then
        cat > /dev/null
    fi
}

cmd() {
    verbose + "$(quote "$@")"
    "$@"
}

check_path() {
    local FILE="$1"
    local INFO="$2"
    shift 2

    verbose + check_path "$FILE" "$@"
    while [ $# -gt 0 ]; do
        ! [[ "$1" =~ ^-[a-z]{2,}$ ]] || { set -- $(echo "${1:1}" | sed 's/./-& /g') "${@:2}"; continue; }
        ! [[ "$1" =~ ^\+[a-z]{2,}$ ]] || { set -- $(echo "${1:1}" | sed 's/./+& /g') "${@:2}"; continue; }
        case "$1" in
            "-e") [ -e "$FILE" ] || { echo "$INFO ${FILE@Q}: No such file or directory" >&2; return 1; } ;;
            "+e") [ ! -e "$FILE" ] || { echo "$INFO ${FILE@Q}: File or directory exists" >&2; return 1; } ;;
            "-f") [ -f "$FILE" ] || { echo "$INFO ${FILE@Q}: Not a file" >&2; return 1; } ;;
            "+f") [ ! -f "$FILE" ] || { echo "$INFO ${FILE@Q}: File exists" >&2; return 1; } ;;
            "-d") [ -d "$FILE" ] || { echo "$INFO ${FILE@Q}: Not a directory" >&2; return 1; } ;;
            "+d") [ ! -d "$FILE" ] || { echo "$INFO ${FILE@Q}: Directory exists" >&2; return 1; } ;;
            "-h") [ -h "$FILE" ] || { echo "$INFO ${FILE@Q}: Not a symbolic link" >&2; return 1; } ;;
            "+h") [ ! -h "$FILE" ] || { echo "$INFO ${FILE@Q}: Symbolic link exists" >&2; return 1; } ;;
            "-r") [ -r "$FILE" ] || { echo "$INFO ${FILE@Q}: Permission denied (not readable)" >&2; return 1; } ;;
            "-w") [ -w "$FILE" ] || { echo "$INFO ${FILE@Q}: Permission denied (not writable)" >&2; return 1; } ;;
            "-x") [ -x "$FILE" ] || { echo "$INFO ${FILE@Q}: Permission denied (not executable)" >&2; return 1; } ;;
            "-s") [ -z "$(find "$FILE" -maxdepth 0 -empty 2> /dev/null)" ] \
                || { echo "$INFO ${FILE@Q}: File or directory is empty" >&2; return 1; } ;;
            "+s") [ -n "$(find "$FILE" -maxdepth 0 -empty 2> /dev/null)" ] \
                || { echo "$INFO ${FILE@Q}: File or directory is not empty" >&2; return 1; } ;;
            *) echo "Invalid $INFO ${FILE@Q}" >&2; return 1 ;;
        esac
        shift
    done
}

get_random() {
    tr -dc 'A-Za-z0-9' < /dev/urandom 2> /dev/null | head -c "$1" ||:
}
