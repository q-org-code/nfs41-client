# Licenses

This repository holds our own scripts, tests and documents, plus patches to two upstream projects. It does not contain upstream source code (the `vendor/` and `build/` folders are git-ignored).

| Part | License |
|---|---|
| Scripts (`scripts/`), tests (`tests/`), documents (`docs/`, `plans/`, `README.md`, `CHANGELOG.md`) | MIT, see [LICENSE](LICENSE) |
| `patches/0001-nfs-v4.1-dialect.patch`, `patches/0003-nfs-v4-retry-delay-grace.patch` (against [libnfs](https://github.com/sahlberg/libnfs) 8.0.0) | GNU LGPL 2.1, the license of the code they change |
| `patches/0002-fuse-nfs-macos-timespec.patch`, `patches/0004-fuse-nfs-swallow-appledouble.patch` (against [fuse-nfs](https://github.com/sahlberg/fuse-nfs) `6444bfc`) | GNU GPL 3.0, the license of the code it changes |

A built `fuse-nfs` binary is covered by the GPL 3.0. If you distribute one, you must offer its source, including these patches. `tests/*.c` link libnfs (LGPL) as a shared library. [fuse-t](https://www.fuse-t.org/) is a separate product with its own license.
