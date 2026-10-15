# Changelog

All notable changes to this project are recorded here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html); see [docs/VERSIONING.md](docs/VERSIONING.md). Versions below 1.0.0 are pre-release: the interface and mount options may change in any minor version.

## [Unreleased]

## [0.5.1] - 2026-10-15
### Added
- `LICENSE` (MIT, for our own scripts, tests and documents) and `NOTICE.md` (the patches keep their upstream licenses: LGPL 2.1 for libnfs, GPL 3.0 for fuse-nfs; a built `fuse-nfs` binary is GPL 3.0).

## [0.5.0] - 2026-10-15
### Added
- `patches/0003-nfs-v4-retry-delay-grace.patch`: libnfs retries a compound the server answers with `NFS4ERR_DELAY` or `NFS4ERR_GRACE` (RFC 8881 15.1.1), up to 30 times, waiting 100 ms longer each time up to 1 s.
- `tests/unlink_test.c`: unlinks one file and prints libnfs's error text.
### Fixed
- `rm` through FUSE of a file that another client (the macOS kernel client) had read failed with `Input/output error` (the server answered `NFS4ERR_DELAY` while recalling a delegation). With 0003 the same test removes 8 of 8 files.
- `scripts/local_suite.sh` checked some results through the kernel client's stale cache; it now checks the FUSE view. 35 of 35 checks pass.

## [0.4.1] - 2026-10-15
### Added
- Phase 4b local tests (`scripts/local_suite.sh`, `docs/phase4b_local_tests.md`): large files, names, links, attributes, a 2,000-file directory, 8 parallel writers and readers.
- README status line.

## [0.4.0] - 2026-10-15
### Added
- First commit of the project (work of 2026-10-14): `patches/0001-nfs-v4.1-dialect.patch` (NFS 4.1 in libnfs 8.0.0), `patches/0002-fuse-nfs-macos-timespec.patch`, the fault-injection scripts and tests, the implementation plan, and the findings for Phases 0 to 4.
- With `timeo=100&retrans=0&autoreconnect=-1&tcp-syncnt=2`, a NAS outage of 60 s gives an error within 11-12 s and recovery in about 10 s.

[Unreleased]: https://github.com/q-org-code/nfs41-client/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/q-org-code/nfs41-client/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/q-org-code/nfs41-client/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/q-org-code/nfs41-client/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/q-org-code/nfs41-client/releases/tag/v0.4.0
