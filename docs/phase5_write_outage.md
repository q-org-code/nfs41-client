# Phase 5 test: writes during an outage (2026-10-15, claude_m1)

Script: `scripts/p5_write_outage.sh`. fuse-nfs on fuse-t against a scratch dir at the root of share REF, URL options `timeo=100&retrans=0&autoreconnect=-1&tcp-syncnt=2`. The NAS address used by the mount (192.168.50.213) is blocked for 60 s with `pf` (root, `scripts/fault.sh`). Writer A appends one numbered line per second; writer B copies a 20 MB file starting 10 s into the outage, and again after recovery. Logs: `docs/phase5_write_outage*.log`. Two runs; run 1's timing was off (the block started about 30 s after the log's "fault start" because of the password dialog, and `$?` was lost in the log line), so its numbers are only used where they agree with run 2.

Times below are seconds after the block started (b+N). The block ended at b+60.

## Results
| | Run 2 | Criterion |
|---|---|---|
| First append after the block | blocked 48 s, then failed (run 1: 36 s) | error within 15 s: **not met** |
| 20 MB copy started at b+10 | failed after 62 s | error within 15 s: **not met** |
| Later appends during the outage | each failed after 11 s | within 15 s: met |
| Appends after the block ended | worked again at b+85, 25 s after the block ended | recovery within 30 s: met (reads recovered in about 10 s in Phase 4) |
| New 20 MB file right after recovery | `cp` failed at once with `Input/output error`, in both runs | works after recovery: **not met** |
| Lines appended before and after the outage | all well-formed, none garbled (run 1: 52 of 52); the failed appends are simply absent | no corruption: met |
| Processes stuck in `U` | 1 to 3 during the outage, none left afterwards in run 1 | none beyond a short window: partly met |

## fuse-t crashed in run 2
At 09:11:13, about 10 s after the failed copy, fuse-t's `go-nfsv4` process (1.2.9) died with `SIGABRT` after an invalid memory access at address `0x60` (a nil pointer in the Go runtime). `fuse-nfs` exited with it, but the macOS mount stayed. An `rm` on the dead mount sat in state `U` for over 7 minutes until `umount -f` (no root needed) removed the mount. In Phase 3 we saw the reverse: killing only `fuse-nfs` made `stat` fail at once, so a hung mount appears only when fuse-t's server process itself dies. The crash report is in `~/Library/Logs/DiagnosticReports/go-nfsv4-1.2.9-2026-10-15-091114.ips` (not copied here; it holds local paths).

## Conclusion
Writes need more work before the Phase 5 cutover. Reads and stat calls meet the criteria; the first in-flight write, a large write started mid-outage, and creating a file just after recovery do not. The crash is in fuse-t, not in our patches, but it matters because it turns a clean failure into a hung mount.

## Next steps
1. Run the same test with libnfs debug output (`debug=3` in the URL) and a packet capture to see why the first write takes 36-48 s (a candidate is the write path waiting out an RPC timeout plus a session re-establishment), and why a file create fails right after recovery.
2. Report the fuse-t crash to the fuse-t project with the crash report (needs the Owner's OK, like any upstream report).
3. Try `umount -f` plus remount from a watchdog, as the existing NFS watchdog does for kernel mounts, so a dead fuse-t server never leaves a hung mount.
4. Still to do with the Owner present: the NAS NFS-service reload and sleep/wake tests.
