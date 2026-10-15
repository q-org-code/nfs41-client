# Phase 1-2 findings (2026-10-14, claude_m1)

Patch: `patches/0001-nfs-v4.1-dialect.patch` (3 files, +70/-3) on libnfs 8.0.0. Adds `NFS_V4_1` (41), URL `?version=4.1`, and routes it through the existing 4.2 session code (EXCHANGE_ID, CREATE_SESSION, SEQUENCE, RECLAIM_COMPLETE) with minor version 1. 4.2-only calls (fallocate, SEEK_HOLE/DATA) stay 4.2-only.

Phase 1 (QNAP 192.168.50.214:/REF, 215:/AIMem):
- Unmodified libnfs: `?version=4.1` -> "NFS version 4.1 is not supported".
- Unmodified/patched `?version=4.2` -> EXCHANGE_ID fails NFS4ERR_MINOR_VERS_MISMATCH (QNAP is 4.1 only).
- Patched `?version=4.1`: nfs-ls lists REF and the vault; nfs-cat of a vault file has the same SHA-256 as the kernel mount.

Phase 2:
- 100 MB random file: nfs-cp write then kernel read, and kernel write then nfs-cat read: SHA-256 equal both ways (read 115 MB/s).
- 2,000 files: listing returned all entries (4,000 incl. the kernel client's `._` AppleDouble files, all unique).
- `tests/ops_test.c`: mkdir, create, write, rename, stat, read, unlink, rmdir all OK.
- Not yet tested: concurrency, files >100 MB, permissions/chmod, symlinks, long names, server restart (Phase 4).
