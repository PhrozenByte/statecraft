StateCraft Example - Backup a FCOS Server
=========================================

In this example, we will walk through how to use **StateCraft** to back up data from a **Fedora CoreOS** (FCOS) server.

---

📚 Contents
----------

* 🔍 [Scenario](#-scenario)
* ⚙️ [Create StateCraft's `paths.d` directory](#%EF%B8%8F-create-statecrafts-pathsd-directory)
* 🛠️ [Create a custom state script for Podman containers](#%EF%B8%8F-create-a-custom-state-script-for-podman-containers)
* 🚀 [Running StateCraft](#-running-statecraft)

---

🔍 Scenario
----------

Let's assume you're running a [Fedora CoreOS](https://fedoraproject.org/coreos/) (FCOS) server and want to back up specific data from it.

First, you'll need to install StateCraft. The installation process is straightforward: download the latest release and run `make install` (you can find more detailed installation instructions in StateCraft's `README.md`).

Since FCOS is an immutable operating system designed to run [Docker](https://www.docker.com/) and [Podman](https://podman.io/) containers, there's no need to back up the root directory (`/`). Instead, we'll focus on information about the running FCOS installation, the system's data stored in `/var`, and the configuration stored in `/etc`. Additionally, we want to include information about the Podman containers currently running on the server.

To better manage the data on your FCOS server, you've created separate [Btrfs](https://btrfs.readthedocs.io/en/latest/) partitions for `/var` and `/srv` (which is a symlink to `/var/srv`) to store the data of your containers. The `/var` partition is a plain Btrfs partition with just one subvolume, while the `/srv` partition adopts Snapper's flat subvolume layout, meaning you've created multiple Btrfs subvolumes like `@`, `@foo`, and `@bar` on the root subvolume. You then mount the `@` subvolume at `/srv`, the `@foo` subvolume at `/srv/containers/foo`, and the `@bar` subvolume at `/srv/containers/bar`.

In total, you'll need to create seven StateCraft paths:

1. `/etc` as a read-only bind mount. No snapshot support here because FCOS uses XFS for its root partition, but the configuration files don't change at runtime anyway.
2. `/var` as a read-only Btrfs snapshot of the root subvolume, created as `/.snapshots/snap-XXXXXXXXXX` on the root subvolume (mounted at `/var/.snapshots/` on the live system).
3. `/srv` as a read-only Btrfs snapshot of the `@` subvolume, created as `/@_snap-XXXXXXXXXX` on the root subvolume (the root subvolume isn't actually mounted on the live system).
4. `/srv/containers/foo` as a read-only Btrfs snapshot of the `@foo` subvolume, created as `/@foo_snap-XXXXXXXXXX` on the root subvolume.
5. `/srv/containers/bar` as a read-only Btrfs snapshot of the `@bar` subvolume, created as `/@bar_snap-XXXXXXXXXX` on the root subvolume.
6. `/fcos-release.json` as a static JSON file containing information about the running FCOS installation.
7. `/podman-containers.json` as a static JSON file containing information about the Podman containers currently running on the FCOS server.

This might sound like a lot of work, but the provided StateCraft state scripts do most of the heavy lifting. All you need to do is create symbolic links to encode the desired mounts and the `/fcos-release.json` file. For `/podman-containers.json`, you'll need to create a custom state script — but that's fairly simple, too.

⚙️ Create StateCraft's `paths.d` directory
-----------------------------------------

Let's assume you store the state scripts in `/etc/backup/paths.d` and that you've installed StateCraft to `/usr/local`. Here's how to set everything up:

```sh
# Bind mount /etc read-only
ln -s "/usr/local/lib/statecraft/state-scripts/bind.sh" "/etc/backup/paths.d/$(statecraft -e "/etc").state.sh"

# Mount read-only Btrfs snapshot of /var
ln -s "/usr/local/lib/statecraft/state-scripts/btrfs.sh" "/etc/backup/paths.d/$(statecraft -e "/var").state.sh"

# Mount read-only Btrfs snapshots of /srv and its subvolumes
ln -s "/usr/local/lib/statecraft/state-scripts/btrfs.sh" "/etc/backup/paths.d/$(statecraft -e "/srv").state.sh"
ln -s "/usr/local/lib/statecraft/state-scripts/btrfs.sh" "/etc/backup/paths.d/$(statecraft -e "/srv/containers/foo").state.sh"
ln -s "/usr/local/lib/statecraft/state-scripts/btrfs.sh" "/etc/backup/paths.d/$(statecraft -e "/srv/containers/bar").state.sh"

# Create FCOS status information at /fcos-release.json
ln -s "/usr/local/lib/statecraft/state-scripts/fcos-release.sh" "/etc/backup/paths.d/$(statecraft -e "/fcos-release.json").state.sh"

# Create custom mount script for /podman-containers.json
touch "/etc/backup/paths.d/$(statecraft -e "/podman-containers.json").state.sh"
```

🛠️ Create a custom state script for Podman containers
----------------------------------------------------

Our custom state script `/etc/backup/paths.d/podman\x2dcontainers.json.state.sh` is fairly simple. The `setup_path` function calls the `_setup_podman_containers_file` function, which in turn writes the output of the `_podman_containers` function to `/podman-containers.json`. The `_podman_containers` function returns a single JSON dictionary with the user-indexed output of `podman ps --format=json` for all users with a `/run/user/$UID/containers` directory (i.e., users with currently or previously running Podman containers). Besides calling `_podman_containers` and creating `/podman-containers.json`, the `_setup_podman_containers_file` function also tells StateCraft with the [`trap_exit` function](./src/lib/statecraft/include/traps.sh) to delete that file after finishing the backup command. Lastly, the script checks for runtime dependencies: it requires [`jq`](https://jqlang.org/) to manipulate JSON, [`sudo`](https://www.sudo.ws/) (or a compatible alternative) to call `podman` for different users, and Podman itself.

```sh
[ -x "$(which jq 2> /dev/null)" ] || { echo "Missing dependency for custom state script: jq" >&2; exit 1; }
[ -x "$(which sudo 2> /dev/null)" ] || { echo "Missing dependency for custom state script: sudo" >&2; exit 1; }
[ -x "$(which podman 2> /dev/null)" ] || { echo "Missing dependency for custom state script: podman" >&2; exit 1; }

_podman_containers() {
    (
        [ ! -d /run/containers/ ] || cmd sudo -i -- podman ps --format=json | jq -c '{"root": .}'
        for PODMAN_RUN_DIR in /run/user/*/containers/; do
            PODMAN_USER="$(id -un "$(basename "$(dirname "$PODMAN_RUN_DIR")")")"
            cmd sudo -i -u "$PODMAN_USER" -- podman ps --format=json | jq -c --arg user "$PODMAN_USER" '{$user: .}'
        done
    ) | jq -s
}

_setup_podman_containers_file() {
    local ID="$1"

    # create status file
    local FILENAME="$(unescape_path "$ID")"
    check_path "$TARGET_DIR$FILENAME" "Invalid path ${ID@Q}: Invalid Podman container info file" +e

    quiet "Write Podman container info to ${FILENAME@Q}"
    mkmountpoint "$TARGET_DIR" "$ID" "$(dirname "$FILENAME")"
    _podman_containers > "$TARGET_DIR$FILENAME"

    # delete status file
    trap_exit rm "$TARGET_DIR$FILENAME"
    trap_exit quiet "Delete ${FILENAME@Q}"

    return 0
}

setup_path() {
    _setup_podman_containers_file "$@"
}
```

🚀 Running StateCraft
--------------------

After setting up the symbolic links and the custom state script, your `/etc/backup/paths.d/` directory will look like this:

```console
$ tree -p /etc/backup/paths.d/
[drwxr-xr-x]  /etc/backup/paths.d/
├── [lrwxrwxrwx]  etc.state.sh -> /usr/local/lib/statecraft/state-scripts/bind.sh
├── [lrwxrwxrwx]  fcos\x2drelease.json.state.sh -> /usr/local/lib/statecraft/state-scripts/fcos-release.sh
├── [-rw-r--r--]  podman\x2dcontainers.json.state.sh
├── [lrwxrwxrwx]  srv-containers-bar.state.sh -> /usr/local/lib/statecraft/state-scripts/btrfs.sh
├── [lrwxrwxrwx]  srv-containers-foo.state.sh -> /usr/local/lib/statecraft/state-scripts/btrfs.sh
├── [lrwxrwxrwx]  srv.state.sh -> /usr/local/lib/statecraft/state-scripts/btrfs.sh
└── [lrwxrwxrwx]  var.state.sh -> /usr/local/lib/statecraft/state-scripts/btrfs.sh

1 directory, 7 files
```

Once everything is set up, you can run StateCraft. Let's assume your backup program is called `backup` and simply creates a backup of the current working directory. You would run StateCraft like this:

```console
$ sudo statecraft -p "/etc/backup/paths.d/" -- backup
```

This will execute the `backup` command within the context of the state defined in `/etc/backup/paths.d/`, i.e. a read-only copy of `/etc`, read-only snapshots of `/var` and `/srv` (including its submounts), as well as the `/fcos-release.json` and `/podman-containers.json` status files.
