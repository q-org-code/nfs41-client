# Phase 0 findings (2026-10-14, claude_m1)

Test: scratch NFS 4.1 mount of REF via 192.168.50.213, `hard,deadtimeout=20`, reader stat-ing a 1 MB file every second; pf blocked outbound TCP to .213 for 60 s (14:45:03-14:46:03). Logs: dead20.log, dead20.fault; scripts: case.sh, fault.sh.

- The reader blocked in state U for 29 s, then the kernel force-unmounted the mount and the call returned rc=1.
- Later calls failed at once (mount gone). No process stayed in U.
- The mount did NOT return when the NAS came back. Phase 4 criteria (error <=15 s, recovery <=30 s) are not met: 29 s, no auto-recovery.
- `soft` is rejected with 4.1 (EINVAL).
- Control (plain `hard`) was not run; the 10-08 and 10-14 wedges are the evidence of unbounded blocking.
- Untested: whether autofs remounts after the forced unmount (needs a scratch autofs entry; /etc change, Calvin to approve).

Conclusion: `deadtimeout` bounds the hang but does not recover. The user-space client stays justified; deadtimeout is a stopgap.
