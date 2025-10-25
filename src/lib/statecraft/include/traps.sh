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

__TRAPS_EXIT=()
__RUNNING=

trap_exit() {
    __TRAPS_EXIT+=( "$(quote "$@")" )
}

trap_exit_eval() {
    __TRAPS_EXIT+=( "$*" )
}

__trap_exit_exec() {
    local EXIT=$?
    trap - ERR EXIT

    set +e +o pipefail

    __trap_verbose() {
        local TRAP="$1"
        [[ " echo verbose quiet " != *" ${TRAP%% *} "* ]] || return 0
        [[ "$TRAP" != *" | verbose" ]] || TRAP="${TRAP:0:-10}"
        [[ "$TRAP" != *" | quiet" ]] || TRAP="${TRAP:0:-8}"
        verbose + "$TRAP"
    }

    # forward unix signals to command, if running
    if [ -n "$__RUNNING" ]; then
        (( EXIT <= 128 || EXIT > 192 )) \
            && { cmd pkill -TERM -P "$$" ||:; } \
            || { cmd pkill -"$(( EXIT - 128 ))" -P "$$" ||:; }
    fi

    # dismantle mounts in reverse order
    local INDEX=0
    for (( INDEX=${#__TRAPS_EXIT[@]}-1 ; INDEX >= 0 ; INDEX-- )); do
        __trap_verbose "${__TRAPS_EXIT[$INDEX]}"
        eval "${__TRAPS_EXIT[$INDEX]}"
    done

    # we're ~always~ ~most of the time~ _sometimes_ successful ;-)
    exit $EXIT
}

trap __trap_exit_exec ERR EXIT
