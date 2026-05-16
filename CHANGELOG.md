StateCraft Changelog
====================

### Version 1.2.0
Released: 2026-05-16

New Features:
* New `external-drive.sh` state script to wait for an external drive to be mounted and bind mounting one of its sub-directories [[e76441d]](https://github.com/PhrozenByte/statecraft/commit/e76441d)

Improvements & Fixes:
* Use Bash `type -P` for `COMMAND` to force `$PATH` traversal [[399c985]](https://github.com/PhrozenByte/statecraft/commit/399c985)
* Improve `$LIB_DIR` detection [[502c0c0]](https://github.com/PhrozenByte/statecraft/commit/502c0c0)
* Add `mountinfo_dev` helper [[4db240e]](https://github.com/PhrozenByte/statecraft/commit/4db240e)

### Version 1.1.0
Released: 2026-05-14

New Features:
* Allow transforming paths with `<target>+<source>.state.sh` state scripts [[b7ffa7f]](https://github.com/PhrozenByte/statecraft/commit/b7ffa7f) [[ab2a2c6]](https://github.com/PhrozenByte/statecraft/commit/ab2a2c6)

Security:
* Check permissions before running state scripts [[81afa34]](https://github.com/PhrozenByte/statecraft/commit/81afa34)

Improvements & Fixes:
* Harmonize Makefile `libdir` variable with GNU conventions [[4a267a6]](https://github.com/PhrozenByte/statecraft/commit/4a267a6)
* Create `_btrfs_snapshot_mount` and `_btrfs_snapshot_umount` functions from main `_setup_btrfs_mount` of `btrfs.sh` [[75a0551]](https://github.com/PhrozenByte/statecraft/commit/75a0551)
* Minor code improvements and formatting [[075f965]](https://github.com/PhrozenByte/statecraft/commit/075f965) [[d1cce59]](https://github.com/PhrozenByte/statecraft/commit/d1cce59)

Miscellaneous & Docs:
* Install USAGE_EXAMPLE.md to `docdir` with `make install` [[6877afc]](https://github.com/PhrozenByte/statecraft/commit/6877afc)
* Mention GNU findutils as runtime dependency in README.md [[c8fc8ce]](https://github.com/PhrozenByte/statecraft/commit/c8fc8ce)
* Mention `$SELINUX` and `${PATHS[@]}` variables in README.md [[c0b98d9]](https://github.com/PhrozenByte/statecraft/commit/c0b98d9)
* Bump copyright year [[75c6f9d]](https://github.com/PhrozenByte/statecraft/commit/75c6f9d)

### Version 1.0.2
Released: 2025-11-13

* Don't install `.gitignore` files [[265fa73]](https://github.com/PhrozenByte/statecraft/commit/265fa73)
* Update README.md to include AUR package [[c7692cd]](https://github.com/PhrozenByte/statecraft/commit/c7692cd)

### Version 1.0.1
Released: 2025-11-07

* Simplify code and remove some leftovers [[468294f]](https://github.com/PhrozenByte/statecraft/commit/468294f)

### Version 1.0.0
Released: 2025-10-25

* Initial public release
