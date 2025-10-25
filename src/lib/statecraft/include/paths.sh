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

escape_path() {
    local INPUT="$1"

    # `systemd-escape` also allows for limited normalization as long as the path is still unambiguous
    local NORMALIZED="$(sed -e '/^[^/]/q;s#///*#/#g;s#/\.\(/\.\)*\(/\|$\)#/#g;s#\(.\)/$#\1#g' <<< "$INPUT")"

    # neither empty or relative paths, nor paths with ../ are allowed
    if [ -z "$NORMALIZED" ] || [ "${NORMALIZED:0:1}" != "/" ] || [[ "$NORMALIZED" =~ /\.\.(/|$) ]]; then
        echo "Failed to escape path ${INPUT@Q}: Must be a normalized absolute file system path" >&2
        return 1
    fi

    # the root path '/' is represented by '-'
    [ "$NORMALIZED" != "/" ] || { echo "-"; return 0; }

    # escape path after removing the leading slash
    local OUTPUT= CHAR= POS=0
    while IFS= read -n 1 -r CHAR; do
        if [ "$CHAR" == "/" ]; then
            # replace slashes by '-'
            OUTPUT+="-"
        elif [[ "$CHAR" =~ ^[a-zA-Z0-9:_]$ ]] || { [ "$CHAR" == "." ] && (( POS > 0 )); }; then
            # ASCII letters, numbers, colons, underscores, and dots can be kept as-is
            # exception: for paths starting with a dot (like '/.foo') we escape the dot
            # regex pattern matching is limited to ASCII characters due to LC_ALL=C.UTF-8
            OUTPUT+="$CHAR"
        else
            # replace any other character with its hex representation (using `od`)
            OUTPUT+="$(printf '%s' "$CHAR" | od -v -An -tx1 | sed -e 's# #\\x#g')"
        fi
        ((++POS))
    done < <(printf '%s' "${NORMALIZED#/}")

    # print result
    echo "$OUTPUT"
}

unescape_path() {
    local INPUT="$1"

    # the root path '/' is represented by '-'
    [ "$INPUT" != "-" ] || { echo "/"; return 0; }

    # escaped paths consist of ASCII letters, numbers, colons, dots, underscores, minuses, and escape sequences only
    # we also reject non-normalized (e.g. '/foo//bar', '/foo/bar/', '/foo/./bar', '/../foo/bar') and empty paths
    # this is also enforced with escaped dots and slashes; lastly, escaped paths must not start with an unescaped dot
    # regex pattern matching is limited to ASCII characters due to LC_ALL=C.UTF-8
    if [ -z "$INPUT" ] || [[ ! "$INPUT" =~ ^([a-zA-Z0-9:._-]|\\x[0-9a-f]{2})+$ ]] \
        || [[ "$INPUT" =~ (^|-|\\x2f)(\.|\\x2e){,2}(-|\\x2f|$) ]] || [ "${INPUT:0:1}" == "." ]
    then
        echo "Failed to unescape path ${INPUT@Q}: Must be an escaped normalized absolute file system path" >&2
        return 1
    fi

    # replace '-' by slashes and add a leading slash (all escaped paths are absolute)
    # printf additionally replaces escaped characters (e.g. '\x20' gets ' ')
    printf "/$(sed -e 's#-#/#g' <<< "$INPUT")\n"
}
