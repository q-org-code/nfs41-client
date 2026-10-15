#!/bin/zsh
# usage: scripts/build.sh [work-dir]   Build the patched libnfs and fuse-nfs from upstream sources (macOS, Apple silicon or Intel).
# Output: <work-dir>/libnfs/build/lib/libnfs.dylib and <work-dir>/fuse-nfs/fuse-nfs. Default work-dir: ./work (git-ignored).
# Needs: clang (Command Line Tools), cmake, git, patch, pkg-config, and fuse-t (brew install --cask fuse-t).
set -eu
REPO=${0:A:h:h}; W=${1:-$REPO/work}; mkdir -p $W; W=${W:A}
LIBNFS_URL=https://github.com/sahlberg/libnfs;   LIBNFS_REV=5b1bc60260b5ddac34900c5315010b88b73e7edd   # 8.0.0
FUSENFS_URL=https://github.com/sahlberg/fuse-nfs; FUSENFS_REV=6444bfc52db44ab93c8930e327a8802a08d2060e

for t in clang cmake git patch pkg-config; do command -v $t >/dev/null || { echo "missing: $t"; exit 1; }; done
pkg-config --exists fuse-t || { echo "missing: fuse-t (brew install --cask fuse-t)"; exit 1; }

fetch() {   # url rev dir
  [ -d $3/.git ] || git clone -q $1 $3
  git -C $3 checkout -q -f $2 && git -C $3 clean -qfdx
}

echo "== libnfs $LIBNFS_REV"; fetch $LIBNFS_URL $LIBNFS_REV $W/libnfs
for p in 0001-nfs-v4.1-dialect 0003-nfs-v4-retry-delay-grace; do patch -s -p1 -d $W/libnfs < $REPO/patches/$p.patch; done
cmake -S $W/libnfs -B $W/libnfs/build -DCMAKE_BUILD_TYPE=Release -DENABLE_NFS4_2=ON -DENABLE_EXAMPLES=OFF -DENABLE_TESTS=OFF -DENABLE_DOCUMENTATION=OFF >/dev/null
cmake --build $W/libnfs/build -j"$(sysctl -n hw.ncpu)" >/dev/null

echo "== fuse-nfs $FUSENFS_REV"; fetch $FUSENFS_URL $FUSENFS_REV $W/fuse-nfs
for p in 0002-fuse-nfs-macos-timespec 0004-fuse-nfs-swallow-appledouble; do patch -s -p1 -d $W/fuse-nfs < $REPO/patches/$p.patch; done
echo '#define HAVE_FUSE_H 1' > $W/fuse-nfs/config.h
clang -O2 -w -D_FILE_OFFSET_BITS=64 $(pkg-config --cflags fuse-t) -I$W/libnfs/include \
  $W/fuse-nfs/fuse/fuse-nfs.c -o $W/fuse-nfs/fuse-nfs \
  -L$W/libnfs/build/lib -lnfs -Wl,-rpath,$W/libnfs/build/lib $(pkg-config --libs fuse-t)

echo "built: $W/fuse-nfs/fuse-nfs"; $W/fuse-nfs/fuse-nfs --help 2>&1 | head -3 || true
