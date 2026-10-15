# Phase 3-4 findings (2026-10-14, claude_m1)

## Phase 3: fuse-nfs on fuse-t
- fuse-t 1.2.9 installed (cask, Calvin ran the pkg installer; `pkg-config fuse-t` works). Headers /usr/local/include/fuse, lib /usr/local/lib/libfuse-t.dylib.
- fuse-nfs (sahlberg, commit 6444bfc, 2026-09-26) is one C file. Built with clang directly against patched libnfs; needs `patches/0002-fuse-nfs-macos-timespec.patch` (macOS `st_atimespec` instead of `st_atim`) and an empty-ish `config.h`.
- `fuse-nfs -n "nfs://IP/REF?version=4.1&..." -m <mountpoint>` mounts. 50 MB write through the mount equals the kernel client's view (SHA-256).
- fuse-t exposes the FUSE fs to macOS as a local NFS 4.0 `hard` mount on 127.0.0.1. Killing fuse-nfs with `kill -9` made `stat` fail at once (ENOENT, 0 s); no hang, no process in U.

## Phase 4: NAS blocked 60 s (pf, root dialog; scratch mount via .213, REF/AIMem mounts untouched)
URL options that matter: `timeo=100&retrans=0&autoreconnect=-1&tcp-syncnt=2`.

| Run | First error | Recovery after block removed |
|---|---|---|
| kernel `hard,deadtimeout=20` (Phase 0) | 29 s, then mount force-unmounted | none |
| fuse-nfs, no `tcp-syncnt` | 24 s | none within 40 s (reads kept failing, 11 s each) |
| fuse-nfs + `tcp-syncnt=2` (`docs/phase4/syn2.log`) | 11-12 s | first good read about 10 s (4 s read) after |

Pass criteria: error <= 15 s (met, 11-12 s); no process in U beyond a constant baseline of one unrelated process (met); recovery <= 30 s without manual umount (met, about 10 s). The cause of the earlier non-recovery: libnfs's reconnect `connect()` to the dead address sits in the TCP SYN retry for ~75 s; `tcp-syncnt` bounds it.
Library-level check through a user-space proxy (`scripts/faultproxy.py`, `tests/fault_test.c`): same 11-12 s errors, recovery in ~8 s.
Caveat: fuse-t/NFS attribute caching (acregmin 5 s to acregmax 60 s) answers `stat` of a cached file for the first ~15-25 s of an outage, so callers see stale success, then errors.

## Not yet tested
NFS service reload and NAS reboot on the NAS; M1 sleep/wake (DisplayLink); write under fault (data loss semantics); many concurrent clients; large trees; cutover (Phase 5).
