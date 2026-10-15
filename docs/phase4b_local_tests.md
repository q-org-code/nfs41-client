# Phase 4b: local tests (2026-10-15, claude_m1)

Script: `scripts/local_suite.sh` (fuse-nfs on fuse-t against a scratch dir at the root of share REF, `nfs://192.168.50.213/REF?version=4.1&timeo=100&retrans=0&autoreconnect=-1&tcp-syncnt=2`). Logs: `docs/local_suite_*.log`. Nothing left behind on REF; no `fuse-nfs` process and no `U` process afterwards.

## Passed
- **Large files:** 200 MB and 1,000 MB written through FUSE; SHA-256 equal in the kernel view and the FUSE view. Write speed 100 MB/s (200 MB in 2 s, 1,000 MB in 9 s).
- **Names:** a 255-byte name; spaces in names.
- **Links and attributes:** symlink (readlink the same in both views); hardlink (link count 2); chmod, mtime (`touch -t`), append and truncate (checked in the FUSE view).
- **Directories:** rename, nested mkdir/rmdir chain, a 2,000-file directory listed completely in both views, `rm -rf` of it.
- **Concurrency:** 8 parallel writers of 50 MB (4 s) and 8 parallel readers; all 16 checksums equal.

## Findings
1. **Kernel-client attribute and readdir cache lags (not a defect).** After a change through FUSE, the kernel client still shows old size, mode, mtime and directory contents for up to about a minute. Checks of the other view must wait or use the FUSE view. Same effect as the fuse-t caching already noted in the other direction.
2. **Delete after the kernel client read a file: transient EIO (a real finding).** Write 50 MB files through FUSE, read them through the kernel mount, then `rm` through FUSE: the last four files fail once with `Input/output error`; the same `rm` succeeds on retry. Reproduced twice. Not seen when only FUSE touched the files, or with 5 MB files. Likely cause (not verified): the QNAP answers REMOVE with `NFS4ERR_DELAY` while the kernel client holds a delegation, and libnfs passes that to the application instead of retrying. Matters only while the kernel and FUSE clients both use a share (the fallback arrangement in Phase 5); a single client does not trigger it. **Fixed in v0.5.0 by `patches/0003-nfs-v4-retry-delay-grace.patch`:** confirmed first as `NFS4ERR_DELAY` with `tests/unlink_test.c` (6 of 8 unlinks failed), then, with the patch, 8 of 8 unlinks succeeded (retries took 0-1 s) and the full suite passes 35 of 35 with no I/O errors.
3. **Unicode names:** fuse-t lists a name in decomposed form (NFD) while the kernel client shows the same file composed (NFC). The shell's own lookups work, but a script comparing bytes across the two views can miss. Irrelevant for the vault's ASCII names; note it for macOS-side users.
4. **Cosmetic:** `ls -la` on a FUSE directory prints a nonsense `total` line.

## Still to do
Writes during an outage (needs the root `pfctl` step), NAS service reload and reboot, sleep/wake with DisplayLink: all need Calvin.
