StateCraft
==========

[StateCraft](https://github.com/PhrozenByte/statecraft) is a CLI utility designed for admins seeking a flexible and powerful tool to define arbitrary directory structures through user-provided scripts. Each script controls actions at the path encoded in the script's filename — these actions can include mounting read-only snapshots of filesystems (e.g., with Btrfs or LVM), creating bind mounts, generating archives, collecting system information, writing status files (e.g., listing the packages installed via your Linux distribution's package manager), or performing any other user-defined operation. StateCraft was primarily designed for use with backup software, enabling consistent backups of complex systems, but it can also serve as a universal solution for dynamically creating directory structures.

StateCraft builds the desired directory structure inside a target directory (CLI option `--target`) by executing state scripts (`*.state.sh`) stored in a `paths.d` directory (CLI option `--paths`). After constructing the environment, it runs a specified command (CLI arguments `COMMAND [ARGS]...`) within this context. Upon completion, StateCraft tears down the target directory by reversing the actions taken — i.e., unmounting filesystems, deleting snapshots, removing files and directories, or undoing any other script effects.

Each state script represents a path encoded in its filename. Typically, a symbolic link is created to one of the built-in state scripts. These include scripts for bind mounts ([`bind.sh`](./src/lib/state-scripts/bind.sh)), [Btrfs](https://btrfs.readthedocs.io/en/latest/) snapshots ([`btrfs.sh`](./src/lib/state-scripts/btrfs.sh)), and [LVM](https://sourceware.org/lvm2/) snapshots ([`lvm.sh`](./src/lib/state-scripts/lvm.sh)). Alternatively, you can create a [XZ](https://tukaani.org/xz/)-compressed [tar](https://en.wikipedia.org/wiki/Tar_(computing)) archive of a path ([`tar-xz.sh`](./src/lib/state-scripts/tar-xz.sh)). There also are built-in scripts to gather system information from a [Fedora CoreOS](https://fedoraproject.org/coreos/) (FCOS) server ([`fcos-release.sh`](./src/lib/state-scripts/fcos-release.sh)), and information about the disks backing the mount points ([`disk-info.sh`](./src/lib/state-scripts/disk-info.sh)). However, custom state scripts can also be used. Such custom scripts may not necessarily mount a filesystem; for example, they could create temporary status files containing system information. Refer to StateCraft's documentation for more details. For encoding the path in the script's filename, StateCraft uses the same encoding method Systemd uses for `*.mount` units (see `systemd-escape(1)`). The encoding can be done with `statecraft --escape` (e.g., `statecraft -e "/home/data"`), and decoding with `statecraft --unescape`.

StateCraft was created as a more versatile and powerful alternative to [@PhrozenByte](https://github.com/PhrozenByte)'s [`btrfs-snapshot-run`](https://gist.github.com/PhrozenByte/7aefc19767f51103045d12538173d1b4). However, StateCraft doesn't supersede `btrfs-snapshot-run`: If you only need to create temporary snapshots of a single Btrfs filesystem, you should use the simpler `btrfs-snapshot-run`.

Pull requests adding more built-in state scripts are very welcome, provided they are universally useful. This isn't limited to mounting filesystems (e.g., mounting read-only snapshots of [ZFS](https://openzfs.org) or [bcachefs](https://bcachefs.org/)), but also includes collecting universally useful system information (e.g., installed [Flatpak](https://flatpak.org/) packages or packages from any other Linux package manager). When in doubt, create a pull request — sharing is caring!

StateCraft is free and open-source software, released under the terms of the [GNU General Public License v3](./LICENSE). Pull requests to improve or extend StateCraft, or to fix any issues, are very welcome! However, please open a new issue on GitHub before developing major changes — it's always better to discuss major changes beforehand. If you experience any issues with StateCraft, don't hesitate to open a new issue on GitHub. Please check StateCraft's documentation and previous GitHub issues first.

Made with ♥ by [Daniel Rudolf](https://www.daniel-rudolf.de) ([@PhrozenByte](https://github.com/PhrozenByte)).

---

## Install

StateCraft was written for [GNU Bash](https://www.gnu.org/software/bash/bash.html). The main program depends solely on common Linux utilities (tested with [BusyBox](https://busybox.net/) (just its utilities, not `ash`), and [GNU coreutils](https://www.gnu.org/software/coreutils/) + [`util-linux`](https://en.wikipedia.org/wiki/Util-linux)). However, state scripts may add additional runtime dependencies: `btrfs.sh` depends on `btrfs-progs` (the Btrfs userspace tools), `lvm.sh` depends on `lvm2` (the LVM userspace toolset), `tar-xz.sh` depends on `tar` and `xz`, both `disk-info.sh` and `fcos-release.sh` depend on [`jq`](https://jqlang.org/), `disk-info.sh` requires `lsblk` and `findmnt` from `util-linux`, and `fcos-release.sh` only runs on Fedora CoreOS.

To install StateCraft, you just need to obtain the source code (by either cloning the Git repository or by downloading one of StateCraft's source archives; see [GitHub's releases page](https://github.com/PhrozenByte/statecraft/releases)), and run [`make`](https://en.wikipedia.org/wiki/Make_%28software%29) (e.g., [GNU Make](https://www.gnu.org/software/make/make.html), but it should work with any `make` implementation):

```console
$ git clone https://github.com/PhrozenByte/statecraft.git
$ cd ./statecraft
$ make install
```

This will install StateCraft to `/usr/local` (i.e., `/usr/local/bin/statecraft`). [StateCraft's Makefile](./Makefile) mostly follows [GNU's Makefile Conventions](https://www.gnu.org/software/make/manual/make.html#Makefile-Conventions) and supports its well-known variables (most notably `prefix` and `DESTDIR`). So, if you want to install StateCraft to `/usr` instead, run `make install prefix=/usr`. Installing StateCraft to your home directory is also possible: `make install prefix=~/.local`. There are no build/install dependencies besides StateCraft's runtime dependencies. If you're a package maintainer, you might want to remove state scripts that are not compatible with your Linux distribution.

To uninstall StateCraft, run `make uninstall` with the same variables. However, please note that `make uninstall` does *not* remove skeleton directories. With prefixes like `/usr`, `/usr/local` (default), or `~/.local`, there really is no reason to worry about this. However, e.g., `make uninstall prefix=/opt/statecraft` will *not* remove `/opt/statecraft`, but will leave behind some otherwise empty directories. Just run `rm -rf /opt/statecraft` manually.

---

## Usage

Using StateCraft is simple: Just run the `statecraft` script as follows:

```console
$ statecraft
Usage:
    statecraft [-q|-v] [-p SCRIPTS_DIR] [-t TARGET_DIR] COMMAND [ARG]...
    statecraft -e ABSOLUTE_PATH
    statecraft -u ESCAPED_PATH
```

---

### Running StateCraft

StateCraft's real magic happens within the `SCRIPTS_DIR` directory: With the `-p SCRIPTS_DIR` CLI option (or `--paths=SCRIPTS_DIR`), you tell StateCraft what to create and mount. You do this by either creating custom state scripts declaring the `setup_path` function (written in GNU Bash, details below), or by creating symbolic links to built-in state scripts like `bind.sh` or `disk-info.sh`. The state script's filename encodes the path you want StateCraft to create (whether StateCraft creates a file, directory, or mount point there depends on the state script), followed by `.state.sh`. For example, if you want to create a replica of `/home/daniel/Open Source/statecraft`, you first need to encode the path with `statecraft -e "/home/daniel/Open Source/statecraft"` (which returns `home-daniel-Open\x20Source-statecraft`), and then create a symbolic link `home-daniel-Open\x20Source-statecraft.state.sh` pointing to `/usr/local/lib/statecraft/state-scripts/bind.sh`. This allows you to run `statecraft` with the command you wish to run, e.g., [`tree -p`](https://en.wikipedia.org/wiki/Tree_%28command%29) (matching the `COMMAND [ARG]...` CLI argument). Since mounting usually requires root permissions, we run StateCraft with `sudo`.

```console
$ mkdir ./paths.d
$ ln -s /usr/local/lib/statecraft/state-scripts/bind.sh ./paths.d/$(statecraft -e "/home/daniel/Open Source/statecraft").state.sh
$ sudo statecraft -p ./paths.d tree -p
Create 1 path(s) at '/run/statecraft/RdeU2BSLbT_mount'
Creating '/home/daniel/Open Source/statecraft' with built-in 'bind.sh' script
Bind mount '/home/daniel/Open Source/statecraft'
Run `tree` within '/run/statecraft/RdeU2BSLbT_mount'
[drwx------]  .
└── [drwxr-xr-x]  home
    └── [drwx------]  daniel
        └── [drwxr-xr-x]  Open Source
            └── [drwxr-xr-x]  statecraft
                ├── [-rw-r--r--]  LICENSE
                ├── [-rw-r--r--]  Makefile
                ├── [-rw-r--r--]  README.md
                ├── [-rw-r--r--]  USAGE_EXAMPLE.md
                └── [drwxr-xr-x]  src
                    ├── [drwxr-xr-x]  bin
                    │   └── [-rwxrwxr-x]  statecraft
                    └── [drwxr-xr-x]  lib
                        └── [drwxr-xr-x]  statecraft
                            ├── [drwxr-xr-x]  include
                            │   ├── [-rw-r--r--]  mounts.sh
                            │   ├── [-rw-r--r--]  paths.sh
                            │   ├── [-rw-r--r--]  traps.sh
                            │   └── [-rw-r--r--]  utils.sh
                            ├── [drwxr-xr-x]  paths.d
                            └── [drwxr-xr-x]  state-scripts
                                ├── [-rw-r--r--]  bind.sh
                                ├── [-rw-r--r--]  btrfs.sh
                                ├── [-rw-r--r--]  disk-info.sh
                                ├── [-rw-r--r--]  fcos-release.sh
                                └── [-rw-r--r--]  lvm.sh

12 directories, 14 files
Unmount '/home/daniel/Open Source/statecraft'
```

By default, StateCraft will create the configured directory structure within a randomly named directory below `$XDG_RUNTIME_DIR/statecraft`. If the `$XDG_RUNTIME_DIR` environment variable is not set or is empty, it defaults to `/run` for root, and `/run/user/$UID` for other users. Since mounting filesystems usually requires root permissions, StateCraft typically places the created directory structure below `/run/statecraft`. To change this behavior, pass the `-t TARGET_DIR` CLI option (or `--target=TARGET_DIR`). Please note that even when this CLI option is given, StateCraft will still create a random directory below `$XDG_RUNTIME_DIR/statecraft` to store state data.

StateCraft prints various informational messages to stdout by default. To suppress this, pass the `-q` CLI option (or `--quiet`); StateCraft itself will be silent, but stdout and stderr of `COMMAND` are still passed through as before. To increase verbosity and print debug messages to stderr, pass the `-v` CLI option (or `--verbose`).

---

### Encoding paths in state scripts

As noted earlier, you tell StateCraft the paths to create by encoding them within a state script's filename. StateCraft uses the same encoding method Systemd uses for `*.mount` units (see `systemd-escape(1)`), but comes with its own implementation of the encoding algorithm. To escape a path, run with the `-e ABSOLUTE_PATH` CLI option (or `--escape=ABSOLUTE_PATH`). You must provide a normalized absolute path (i.e., it must start with `/` and not include path components like `..`). Remember to quote escaped paths appropriately, otherwise your shell might interpret escape sequences incorrectly. To reverse StateCraft's escape operation, run with the `-u ESCAPED_PATH` CLI option (or `--unescape=ESCAPED_PATH`). Both commands will output the escaped (with `-e`) or original (with `-u`) path, or print an error message and exit with a non-zero status code in case of invalid inputs.

```console
$ statecraft -e "/home/daniel/Open Source/statecraft"
home-daniel-Open\x20Source-statecraft
$ statecraft -u "home-daniel-Open\x20Source-statecraft"
/home/daniel/Open Source/statecraft
```

---

### Custom state scripts

StateCraft ships with many generally useful state scripts, but sometimes you want to do things that aren't possible with StateCraft's built-in scripts — like not including files as they are on your filesystem, but only what has changed in comparison to some previous state. State scripts are GNU Bash shell snippets that are `source`d by StateCraft's main script. All state scripts must declare the `setup_path` function, which implements the script's functionality. Besides declaring the `setup_path` function and possibly other functions used by `setup_path`, state scripts must not execute any active code besides checking for runtime dependencies.

The `setup_path` function is called by StateCraft with the basename of the state script as its only parameter (i.e., StateCraft `source`s the `home-daniel-Open\x20Source-statecraft.state.sh` script and calls `setup_path "home-daniel-Open\x20Source-statecraft"`). You can use StateCraft's `unescape_path` function (from [`paths.sh`](./src/lib/statecraft/include/paths.sh)) to convert this to an actual filesystem path (i.e., `unescape_path "$1"`). With that information, you can do whatever you want — just make sure that all actions are reversible. Use StateCraft's `trap_exit` and `trap_exit_eval` functions (from [`traps.sh`](./src/lib/statecraft/include/traps.sh)) to specify how to reverse the actions; the commands passed will be called in reverse order.

State scripts can use all of StateCraft's public API defined in the [`include` directory](./src/lib/statecraft/include/), or extend built-in state scripts in the [`state-scripts` directory](./src/lib/statecraft/state-scripts/). Common variables include StateCraft's app name (`$APP_NAME`), version (`$VERSION`), build date (`$BUILD`), a random run ID (`$RUN_ID`; random string with 10 ASCII letters and digits), and the paths to `/usr/local/lib/statecraft` (`$LIB_DIR`) and `/run/statecraft/$RUN_ID` (`$RUN_DIR`). The `--quiet` (`$QUIET` is set to `"y"` if `--quiet` is given, `""` otherwise), `--verbose` (`$VERBOSE` is set to `"y"` if `--verbose` is given, `""` otherwise), `--paths` (`$SCRIPTS_DIR`), `--target` (`$TARGET_DIR`), and `COMMAND [ARGS...]` (`${COMMAND[@]}`) CLI options are readable too.

Check StateCraft's [built-in state scripts](./src/lib/statecraft/state-scripts/), or the small custom state script used in [`USAGE_EXAMPLE.md`](./USAGE_EXAMPLE.md) for examples.

---

### Real-world example

Check out [`USAGE_EXAMPLE.md`](./USAGE_EXAMPLE.md) for a more comprehensive real-world example of how to use StateCraft. The documentation explains how to create a backup of a [Fedora CoreOS](https://fedoraproject.org/coreos/) (FCOS) server using bind mounts, Btrfs snapshots, StateCraft's built-in FCOS status file, and a custom mount script that creates a list of running Podman containers.

---

### CLI options

Here is StateCraft's full CLI help (available with `statecraft --help`):

```
Usage:
    statecraft [-q|-v] [-p SCRIPTS_DIR] [-t TARGET_DIR] COMMAND [ARG]...
    statecraft -e ABSOLUTE_PATH
    statecraft -u ESCAPED_PATH

StateCraft is a CLI tool for creating Linux directory trees via scripts.
It supports mounting snapshots, creating files, archives, and more.
Designed for admins seeking flexible, scriptable backup setups.

Arguments:
  COMMAND [ARG]...  run `COMMAND [ARG]...` within TARGET_DIR

Application options:
  -p, --paths=SCRIPTS_DIR  run state scripts from the given 'paths.d' directory
  -t, --target=TARGET_DIR  create directory structure below the given path
  -q, --quiet              suppress StateCraft's output (doesn't affect COMMAND)
  -v, --verbose            explain what is being done

Path escaping options:
  -e, --escape=ABSOLUTE_PATH   escape absolute path to be used by state scripts
  -u, --unescape=ESCAPED_PATH  unescape and print escaped path

Help options:
      --help     display this help and exit
      --version  output version information and exit

Visit us on GitHub: <https://github.com/PhrozenByte/statecraft>
Made with ♥ by Daniel Rudolf <https://www.daniel-rudolf.de/>
```

---

License & Copyright
-------------------

Copyright (C) 2025  Daniel Rudolf <[https://www.daniel-rudolf.de](https://www.daniel-rudolf.de)>

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3 of the License only.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the [GNU General Public License](./LICENSE) for more details.
