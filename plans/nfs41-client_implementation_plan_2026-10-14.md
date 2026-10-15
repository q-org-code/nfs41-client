# nfs41-client: implementation plan

Written 2026-10-14 by claude_m1 for Calvin. Standard: [[20r-implementation_plan_standard]]; code rules: [[20s-coding_standard]]. **Status: Phases 0 to 4 (main case) done; results in section 9. Phase 5 (cutover) awaits Calvin's approval.**

## 1. Context

The M1 mounts the QNAP shares (`AIMem`, `REF`, `macos-quasaur`) with macOS's kernel NFS client, as `hard` mounts. When the NAS reloads exports, restarts NFS or sleeps/wakes oddly, the AIMem mount goes into `recovery`, and every process that touches it blocks in uninterruptible I/O (state `U`): `herdr server`, Finder, Claude.app, Terminal. It has happened at least twice (2026-10-08, 2026-10-14; see `report_m1_nfs_wedge_ghostty_herdr_2026-10-14`). Calvin recovers by a forced `umount` with a password.

Calvin's goal: a client where a dead server makes calls **fail** (errors) instead of hanging the machine.

## 2. Scope

**In:** an NFS 4.1 client for **macOS on the M1 MacBook Pro (`M1MacBookPro7`) only** (arm64) that mounts the QNAP shares, behaves like a soft mount, and runs beside the kernel client until proven. Built from existing parts, patching only what is missing.

**Out:** Linux hosts (`evo`, `mini` use their kernel client, which works); Sondra's M1 mini (it does not use the NAS); a new NFS server; changes to NAS configuration; replacing autofs before Phase 5.

**Done when:** with the NAS unreachable for 60 seconds, no process on the M1 stays blocked more than 15 seconds on the mount, calls return an error, and the mount recovers by itself when the NAS returns. Verified by fault injection (section 6).

## 3. Approach

What exists (found 2026-10-14, 19l questions 2 to 5):

| Piece | Finding |
|---|---|
| macOS `mount_nfs` | `soft` is **rejected with NFS 4.1** (`Invalid argument`, tested). `hard,deadtimeout=N` **is accepted**: after the mount is unresponsive N seconds it is marked dead and **forcibly unmounted**, which should release the blocked processes. Untested under a real outage. |
| libnfs 8.0.0 | Installed. Speaks NFS 4.0 and 4.2, **refuses 4.1**. It already has the session code 4.2 needs; a 4.1 dialect looks like a small patch. Has `nfs_set_timeout()` and `nfs_set_autoreconnect()`. |
| fuse-nfs | `sahlberg/fuse-nfs`, FUSE filesystem over libnfs, GPL-3.0, last push 2026-09-26. Reuse as the FUSE layer. |
| fuse-t 1.2.9 | Kext-less FUSE for macOS (cask), **not installed**. |
| QNAP | Serves NFS 4.1 only (v3 and v4.0 off). |
| Build tools | Command Line Tools present (clang 21, make, git, SDK). Missing: `cmake`, `autoconf`, `automake`, `pkg-config`. No full Xcode (not needed). |

Recommendation, in order:
1. **Phase 0 first:** test `hard,deadtimeout`. If it frees the processes under a real outage, the freezes are solved by one changed option, and the client becomes optional. Calvin has asked for the client regardless, so the plan carries on, but Phase 0 decides how urgent it is.
2. **Patch libnfs** to add an `NFS_V4_1` dialect (upstreamable, LGPL).
3. **Build fuse-nfs** against the patched libnfs, on fuse-t, with short timeouts and auto-reconnect so failures surface as `EIO`/`ETIMEDOUT`.
4. **Run it beside the kernel mount** on REF first, then AIMem.

## 4. Changes

All new, under `~/Developer/nfs41-client/` unless noted.

| Path | What |
|---|---|
| `vendor/libnfs/` | libnfs v8.0.0 source checkout plus our 4.1 patch (`patches/0001-nfs-v4.1-dialect.patch`) |
| `vendor/fuse-nfs/` | fuse-nfs source checkout (build config only; patches in `patches/`) |
| `build/` | build output (git-ignored) |
| `scripts/` | build and fault-injection helpers (kept to a handful of lines each, tested; see 19l) |
| `tests/` | verification scripts and expected outputs |
| `docs/` | findings and the final report |
| Homebrew | `cmake`, `autoconf`, `automake`, `pkg-config` (Phase 1); cask `fuse-t` (Phase 3) |
| `/etc/auto_nas`, `lan.mallard.*` launchd (Phase 5 only) | mount the FUSE client at login; backups first |

## 5. Steps

**Phase 0: baseline and the native option** (no code; needs Calvin for the root step)
- 0.1 Record current behaviour: `nfsstat -m`, the three mounts' flags.
- 0.2 Fault test on a **scratch mount of REF** (not AIMem): mount with `vers=4.1,hard,intr,deadtimeout=20`, start a reader, block the NAS address with a `pfctl` rule for 60 s (**Calvin approves; root via dialog**), watch the reader and mount state, remove the rule.
- 0.3 Repeat with plain `hard` as the control. Compare.
- 0.4 If `deadtimeout` works: report to Calvin with a proposed `auto_nas` change (**Calvin approves; editing a root file**).

**Phase 1: libnfs 4.1 spike** (depends on 0.1; **needs approval to `brew install` the build tools**)
- 1.1 Check out libnfs v8.0.0; build it unmodified; confirm `nfs-ls` on 4.2 fails as expected against the QNAP.
- 1.2 Add `NFS_V4_1`: minorversion 1 in session setup (EXCHANGE_ID, CREATE_SESSION, SEQUENCE, RECLAIM_COMPLETE) reusing the 4.2 path; no 4.2-only ops.
- 1.3 List and read a file on `192.168.50.214:/REF` read-only.

**Phase 2: protocol correctness** (read-only first)
- Large directory listings (the vault is about 2,100 files), reads, stat, then write, rename, delete on REF only. Compare checksums with the kernel mount.

**Phase 3: FUSE layer** (**needs approval: `brew install --cask fuse-t`**; may need a System Settings step)
- Build fuse-nfs on the patched libnfs; mount REF at a new path, `/Volumes/REF-nfs41`; set `nfs_set_timeout`, autoreconnect; map timeouts to `EIO`.

**Phase 4: failure behaviour** (same fault injection as 0.2, **Calvin approves**)
- NAS unreachable, NFS service reload, NAS reboot, M1 sleep/wake with DisplayLink.

**Phase 5: cutover** (hard to undo; **Calvin approves each**)
- REF first, then AIMem; mount at login via launchd; keep autofs/kernel entries as fallback.

**Phase 6: upstream**
- Offer the 4.1 patch to libnfs.

## 6. Verification

- **Phase 1:** `nfs-ls nfs://192.168.50.214/REF?version=4.1` lists the share; `nfs-cat` returns a known file with the same SHA-256 as via the kernel mount.
- **Phase 2:** round trip of a 100 MB file and a 2,000-file tree, checksums equal, no errors in the log.
- **Phase 4, the pass criterion:** with the NAS blocked for 60 s, `ls` and `cat` on the mount return an error within 15 s; no process is in state `U` for more than 15 s (`ps -axo pid,stat,comm | awk '$2 ~ /U/'`); after the block is removed, access works again within 30 s without a manual `umount`.
- **Control:** the kernel client under the same test shows processes stuck in `U`.

## 7. Rollback

- Phase 0-4 add nothing the M1 depends on: unmount the scratch mount, remove the `pfctl` rule (`pfctl -a ... -F all`, or reboot).
- Homebrew installs: `brew uninstall` the formulae and cask.
- Phase 5: restore `/etc/auto_nas` from the dated backup and unload the launchd job; the kernel mounts are still configured.

## 8. Open questions for Calvin

Answered 2026-10-14: M1 MacBook Pro only (Sondra's M1 mini does not use the NAS; NixOS hosts use the working kernel client); the GPL-3.0 fuse-nfs binary may stay internal; this plan also lives in the vault as `20a-NFS_client`.

Open:
1. Approve Phase 0 and the `pfctl` fault test on a scratch REF mount (root via the admin dialog)?

## 9. Results, Phases 0 to 4 (2026-10-14, claude_m1)

Full logs and scripts are in `~/Developer/nfs41-client/docs/` (`phase0/`, `phase1-2_findings.md`, `phase3-4_findings.md`, `phase4/`). All tests ran against scratch mounts of REF; no production mount was touched.

**Phase 0, native option.** `hard,deadtimeout=20` with a 60 s `pf` block of the NAS address: the reader blocked 29 s in state U, then the kernel force-unmounted the mount (rc=1). The mount did **not** return when the NAS came back. So `deadtimeout` bounds the hang but does not recover; it is a stopgap, and the client stays justified. `soft` is rejected with 4.1 (EINVAL). The plain-`hard` control was skipped (the 10-08 and 10-14 wedges are the evidence). Untested: whether autofs remounts after the forced unmount.

**Phases 1 and 2, libnfs 4.1.** `patches/0001-nfs-v4.1-dialect.patch` (libnfs 8.0.0, +70/-3) adds `NFS_V4_1` and the URL option `?version=4.1`, reusing the 4.2 session code with minor version 1. The QNAP is 4.1 only (4.2 gives NFS4ERR_MINOR_VERS_MISMATCH). Verified against the QNAP: list and cat match the kernel client by SHA-256; a 100 MB file round-trips both ways with equal checksums (read 115 MB/s); a 2,000-file directory lists completely; mkdir, create, write, rename, stat, read, unlink, rmdir all pass (`tests/ops_test.c`).

**Phase 3, FUSE layer.** fuse-t 1.2.9 installed (Calvin ran the installer). fuse-nfs (commit 6444bfc) builds as one C file with clang plus `patches/0002-fuse-nfs-macos-timespec.patch`. fuse-t exposes the mount to macOS as a local NFS 4.0 `hard` mount on 127.0.0.1; a 50 MB write matches the kernel view. `kill -9` of fuse-nfs makes `stat` fail at once, with no hang.

**Phase 4, failure behaviour (main case: NAS unreachable 60 s).** URL options `timeo=100&retrans=0&autoreconnect=-1&tcp-syncnt=2`:

| Run | First error | Recovery |
|---|---|---|
| kernel `hard,deadtimeout=20` | 29 s, then force-unmounted | none |
| fuse-nfs without `tcp-syncnt` | 24 s | none within 40 s |
| fuse-nfs with `tcp-syncnt=2` | 11-12 s | about 10 s |

The pass criteria (error within 15 s, no process in U beyond a one-process baseline, recovery within 30 s without a manual umount) are **met**. Without `tcp-syncnt`, libnfs's reconnect `connect()` sits in about 75 s of SYN retries. Caveat: fuse-t attribute caching (5 to 60 s) serves stale `stat` successes for the first 15 to 25 s of an outage.

**Not yet tested:** NFS service reload and NAS reboot; M1 sleep/wake with DisplayLink; writes during an outage; concurrency; files over 100 MB; permissions, symlinks, long names. **Phase 5 (cutover) and Phase 6 (upstream) are not started; Phase 5 needs Calvin's approval.**

Brew installs made: cmake, autoconf, automake, libtool, pkgconf, cask fuse-t. The repo has no commits.
