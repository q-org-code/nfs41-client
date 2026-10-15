# nfs41-client

A user-space NFS 4.1 client for macOS hosts, so that a dead or restarting NAS makes file calls fail instead of freezing every process that touches the mount.

- Owner: Calvin (quasaur). Started 2026-10-14 by claude_m1. Part of vAIMem v20 ([[20a-Implementation_Plan]] lists it as "20a-NFS_client").
- Status: **Phases 0-4 (main case) done; Phase 4b local tests done 2026-10-15 (docs/phase4b_local_tests.md)**. fuse-nfs on fuse-t over the patched libnfs meets the failure criteria on a scratch mount (errors in 11-12 s, auto-recovery in ~10 s). Remaining: NAS reload/reboot and sleep/wake tests, then Phase 5 cutover (needs approval).
- Plan: [plans/nfs41-client_implementation_plan_2026-10-14.md](plans/nfs41-client_implementation_plan_2026-10-14.md)
- Built on: libnfs (LGPL-2.1), fuse-nfs (GPL-3.0), fuse-t (kext-less FUSE for macOS).
