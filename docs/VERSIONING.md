# Versioning and releases

**Scheme:** [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html), `MAJOR.MINOR.PATCH`. The single source of the current version is the `VERSION` file. Every release is an annotated git tag `vX.Y.Z` and a GitHub release whose notes are copied from `CHANGELOG.md`.

**What counts as the public interface:** the mount command line and URL options this project documents (for example `timeo`, `retrans`, `autoreconnect`, `tcp-syncnt`), the behaviour on a dead or restarting server (errors, no hung processes, recovery), and the patch set in `patches/` applying cleanly to the pinned upstream versions (libnfs 8.0.0, fuse-nfs `6444bfc`).

| Bump | When |
|---|---|
| MAJOR | A documented option is removed or changes meaning, the failure behaviour changes, or the pinned upstream versions change in a way that needs a different patch set. |
| MINOR | A new patch, option, script or test suite; a new supported host setup. |
| PATCH | A fix to a patch, script or document that changes no documented behaviour. |

**Before 1.0.0** (now): the interface may change in any MINOR version. 1.0.0 is cut after the Owner's Phase 5 cutover has run cleanly for a month.

**Patches carry the project version, not the upstream's:** each file in `patches/` is numbered in order of application (`0001-`, `0002-`, ...). A new fix is a new numbered patch; an existing patch is edited only to fix it, and the change is listed under `### Fixed` in the changelog.

## Releasing

1. Move the `[Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading and add its compare link at the bottom.
2. Put `X.Y.Z` in `VERSION`.
3. Run `scripts/local_suite.sh`; it must report `fail=0`. Commit: `Release X.Y.Z`.
4. `git tag -a vX.Y.Z -m "nfs41-client X.Y.Z"` and `git push origin main vX.Y.Z`.
5. `gh release create vX.Y.Z --title "X.Y.Z" --notes-file <the changelog section>`; add `--prerelease` while the version is below 1.0.0.

**Commit messages** are one imperative line (`Fix ...`, `Add ...`), a blank line, then why. Hosts record the installed version with `cat VERSION` in the checkout.
