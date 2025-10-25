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

[ -x "$(type -p jq)" ] \
    || { echo "Missing dependency for 'fcos-release.sh' state script: jq" >&2; exit 1; }
[ -x "$(type -p rpm-ostree)" ] \
    || { echo "Missing dependency for 'fcos-release.sh' state script: rpm-ostree" >&2; exit 1; }
[ "$(source /etc/os-release; echo "${ID:-} ${VARIANT_ID:-}")" == "fedora coreos" ] \
    || { echo "Not running on Fedora CoreOS, thus failed to run 'fcos-release.sh' state script" >&2; exit 1; }

_fcos_release_info() {
    verbose + '< /etc/machine-id'
    local MACHINE_ID="$(< /etc/machine-id)"

    verbose + '( source /etc/os-release; jq … )'
    local FCOS_RELEASE_JSON="$(
        source /etc/os-release

        ARCH="$(uname -m)"
        LOCATION="https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/"
        LOCATION+="$OSTREE_VERSION/$ARCH/fedora-coreos-$OSTREE_VERSION-metal.$ARCH.raw.xz"
        SIGNATURE="$LOCATION.sig"

        jq -n '$ARGS.named' \
            --arg "id" "${ID:-}" \
            --arg "name" "${NAME:-}" \
            --arg "full_name" "${PRETTY_NAME:-}" \
            --arg "variant" "${VARIANT:-}" \
            --arg "variant_id" "${VARIANT_ID:-}" \
            --arg "version" "${VERSION:-}" \
            --arg "version_id" "${VERSION_ID:-}" \
            --argjson "fcos-release" "$(jq -nc '$ARGS.named' \
                --arg "stream" "${RELEASE_TYPE:-}" \
                --arg "version" "${OSTREE_VERSION:-}" \
                --arg "arch" "${ARCH:-}" \
                --argjson "artifact" "$(jq -nc '$ARGS.named' \
                    --arg "location" "${LOCATION:-}" \
                    --arg "signature" "${SIGNATURE:-}")")" \
            --arg "home_url" "${HOME_URL:-}" \
            --arg "support_url" "${SUPPORT_URL:-}"
    )"

    verbose + 'rpm-ostree status --json | jq …'
    local RPM_OSTREE_JSON="$(rpm-ostree status --json \
        | jq '.deployments | map({
            "id", "osname", "version", "checksum", "timestamp",
            "container-image-reference", "container-image-reference-digest",
            "booted", "staged", "pinned", "unlocked",
            "requested-packages", "packages",
            "requested-local-packages", "requested-local-fileoverride-packages",
            "requested-base-removals", "base-removals",
            "requested-base-local-replacements", "base-local-replacements",
            "base-remote-replacements"})')"

    jq -n '$ARGS.named' \
        --arg "machine-id" "$MACHINE_ID" \
        --argjson "fcos" "$FCOS_RELEASE_JSON" \
        --argjson "rpm-ostree" "$RPM_OSTREE_JSON"
}

_setup_fcos_release_file() {
    local ID="$1"

    # create status file
    local FILENAME="$(unescape_path "$ID")"
    check_path "$TARGET_DIR$FILENAME" "Invalid path ${ID@Q}: Invalid Fedora CoreOS release file" +e

    quiet "Write Fedora CoreOS release information to ${FILENAME@Q}"
    mkmountpoint "$TARGET_DIR" "$ID" "$(dirname "$FILENAME")"
    _fcos_release_info > "$TARGET_DIR$FILENAME"

    # delete status file
    trap_exit rm "$TARGET_DIR$FILENAME"
    trap_exit quiet "Delete ${FILENAME@Q}"

    return 0
}

setup_path() {
    _setup_fcos_release_file "$@"
}
