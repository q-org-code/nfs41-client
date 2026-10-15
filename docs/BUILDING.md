# Building and running nfs41-client

nfs41-client is not a program of its own. It is two upstream projects plus our patches:

- **libnfs 8.0.0** (`5b1bc60`) with `0001-nfs-v4.1-dialect` (adds NFS 4.1) and `0003-nfs-v4-retry-delay-grace` (retries `NFS4ERR_DELAY` and `NFS4ERR_GRACE`).
- **fuse-nfs** (`6444bfc`) with `0002-fuse-nfs-macos-timespec` (macOS `st_atimespec` names), built against that libnfs.
- **fuse-t**, a FUSE layer for macOS that needs no kernel extension. It is installed, not built.

Tested on macOS 27 (Apple silicon) with Command Line Tools only; full Xcode is not needed.

## 1. Prerequisites

```
xcode-select --install                  # clang, make, git, patch (skip if already installed)
brew install cmake pkgconf              # the build tools
brew install --cask fuse-t              # FUSE for macOS (asks for your password)
pkg-config --exists fuse-t && echo ok   # must print ok
```

## 2. Build (one command)

```
scripts/build.sh            # builds into ./work (git-ignored), takes about 10 seconds
```

It clones libnfs and fuse-nfs at the pinned commits, applies the patches in order, builds libnfs with CMake and compiles `fuse-nfs` with clang. The result is `work/fuse-nfs/fuse-nfs`; it finds its `libnfs.dylib` in `work/libnfs/build/lib` through an rpath, so keep the `work` folder where it is (or pass another folder: `scripts/build.sh ~/nfs41-build`). Re-running starts from a clean checkout.

The steps by hand, if you want them:

```
git clone https://github.com/sahlberg/libnfs && cd libnfs && git checkout 5b1bc60
patch -p1 < ../patches/0001-nfs-v4.1-dialect.patch
patch -p1 < ../patches/0003-nfs-v4-retry-delay-grace.patch
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_NFS4_2=ON -DENABLE_EXAMPLES=OFF && cmake --build build
cd .. && git clone https://github.com/sahlberg/fuse-nfs && cd fuse-nfs && git checkout 6444bfc
patch -p1 < ../patches/0002-fuse-nfs-macos-timespec.patch
echo '#define HAVE_FUSE_H 1' > config.h
clang -O2 -w -D_FILE_OFFSET_BITS=64 $(pkg-config --cflags fuse-t) -I../libnfs/include fuse/fuse-nfs.c -o fuse-nfs \
  -L../libnfs/build/lib -lnfs -Wl,-rpath,$PWD/../libnfs/build/lib $(pkg-config --libs fuse-t)
```

## 3. Mount a share

```
mkdir -p ~/mnt/ref
work/fuse-nfs/fuse-nfs -n "nfs://192.168.50.214/REF?version=4.1&timeo=100&retrans=0&autoreconnect=-1&tcp-syncnt=2" -m ~/mnt/ref
umount ~/mnt/ref            # to unmount
```

`nfs://<server>/<export>`, then the options after `?`:

| Option | Meaning | Why this value |
|---|---|---|
| `version=4.1` | Use NFS 4.1. Needs patch 0001; stock libnfs only speaks 3, 4.0 and 4.2. | The QNAP NAS answers 4.1 only. |
| `timeo=100` | Wait 10 s (units of 0.1 s) for a reply before giving up on a call. | A dead server turns into an error after about 10 s, not a hang. |
| `retrans=0` | Do not resend a timed-out call. | The first timeout is final. |
| `autoreconnect=-1` | Reconnect forever once the server returns. | The mount recovers by itself (about 10 s in our tests). |
| `tcp-syncnt=2` | Limit TCP connection attempts to 2 SYNs. | Without it each reconnect attempt can sit in about 75 s of SYN retries. |

With these, a NAS that is unreachable for 60 s gives errors within 11-12 s, no process stays blocked, and the mount recovers about 10 s after the NAS returns. (fuse-t's own attribute cache can answer `stat` from memory for the first 15-25 s.)

## 4. Check your build

```
scripts/local_suite.sh                              # uses build/fuse-nfs/fuse-nfs
FUSE_NFS=$PWD/work/fuse-nfs/fuse-nfs scripts/local_suite.sh
```

The suite writes a scratch folder at the root of share `REF` (edit the `IP`, `K` and export name at the top of the script for another share), checks files, names, links, a 2,000-file directory and parallel I/O, and removes everything afterwards. It must end with `RESULT pass=35 fail=0`. The outage tests (`scripts/fault.sh`, `scripts/p4_case.sh`) need root and block the NAS address with `pf`; read them before running.

## 5. Uninstall

Unmount, delete the `work` folder, and `brew uninstall --cask fuse-t`.

## Known limits

- macOS only; the Linux hosts use the kernel client, which works.
- fuse-t lists non-ASCII names decomposed (NFD) where the kernel client shows them composed (NFC).
- The kernel client's own cache can show old data for up to a minute after a change made through this client.
- No launchd job or automount integration yet (planned: Phase 5 in the plan).
