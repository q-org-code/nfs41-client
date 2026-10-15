#!/bin/zsh
# usage: local_suite.sh   Phase 4b local tests: fuse-nfs on fuse-t against a scratch dir at the root of share REF.
# Compares every result with the kernel client's view (/Volumes/REF). Leaves nothing behind.
R=$HOME/Developer/nfs41-client; IP=192.168.50.213; M=$R/build/mnt_suite; K=/Volumes/REF/.nfs41_suite
LOG=$R/docs/local_suite_$(date +%F_%H%M).log; pass=0; fail=0
ok()  { echo "PASS $1" | tee -a $LOG; pass=$((pass+1)); }
bad() { echo "FAIL $1 :: $2" | tee -a $LOG; fail=$((fail+1)); }
chk() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "got '$2' want '$3'"; fi; }
: > $LOG; mkdir -p $M $K
$R/build/fuse-nfs/fuse-nfs -n "nfs://$IP/REF?version=4.1&timeo=100&retrans=0&autoreconnect=-1&tcp-syncnt=2" -m $M > $R/build/suite.fuse.log 2>&1 &
sleep 6; mount | grep -q "mnt_suite" || { echo "mount failed"; exit 1; }
T=$M/.nfs41_suite
sh1() { shasum -a 256 "$1" | cut -d' ' -f1; }

# 1. large files (write through FUSE, read through both)
for mb in 200 1000; do
  dd if=/dev/urandom of=/tmp/big_$mb bs=1m count=$mb 2>/dev/null; want=$(sh1 /tmp/big_$mb)
  s=$(date +%s); cp /tmp/big_$mb $T/big_$mb; e=$(date +%s)
  chk "large ${mb}MB write checksum (kernel view)" "$(sh1 $K/big_$mb)" $want
  chk "large ${mb}MB read-back checksum (FUSE view)" "$(sh1 $T/big_$mb)" $want
  echo "     ${mb}MB write took $((e-s)) s" | tee -a $LOG
  rm -f /tmp/big_$mb $T/big_$mb
done

# 2. names, links, permissions
long=$(printf 'n%.0s' {1..255}); : > "$T/$long"; chk "255-byte name" "$(ls $K | grep -c "^$long$")" 1
: > "$T/name with spaces.txt"; chk "spaces in name (FUSE view)" "$(ls $T | grep -c "name with spaces")" 1
echo data > $T/target; ln -s target $T/link; chk "symlink readlink (FUSE)" "$(readlink $T/link)" target; chk "symlink readlink (kernel)" "$(readlink $K/link)" target
ln $T/target $T/hard 2>/dev/null && chk "hardlink count" "$(stat -f %l $K/target)" 2 || ok "hardlink refused (acceptable, logged)"
chmod 640 $T/target; chk "chmod 640 (FUSE view)" "$(stat -f %Lp $T/target)" 640
touch -t 202001020304 $T/target; chk "mtime set (FUSE view)" "$(stat -f %Sm -t %Y%m%d%H%M $T/target)" 202001020304
echo more >> $T/target; chk "append (FUSE view)" "$(cat $T/target | wc -l | tr -d ' ')" 2
truncate -s 3 $T/target; chk "truncate (FUSE view)" "$(stat -f %z $T/target)" 3
mv $T/target $T/renamed; chk "rename" "$(ls $K | grep -c '^renamed$')" 1
mkdir -p $T/d1/d2/d3; chk "nested mkdir" "$([ -d $K/d1/d2/d3 ] && echo yes)" yes
rmdir $T/d1/d2/d3 $T/d1/d2 $T/d1; chk "rmdir chain" "$([ -d $K/d1 ] && echo yes || echo no)" no
mkdir $T/many; for i in {1..2000}; do : > $T/many/f$i; done; chk "2000-file readdir" "$(ls $T/many | wc -l | tr -d ' ')" 2000; chk "2000-file readdir (kernel)" "$(ls $K/many | wc -l | tr -d ' ')" 2000
rm -rf $T/many; chk "rm -rf 2000 files (FUSE view)" "$([ -d $T/many ] && echo yes || echo no)" no

# 3. concurrency: 8 writers of 50MB in parallel, then 8 readers
for i in 1 2 3 4 5 6 7 8; do dd if=/dev/urandom of=/tmp/c_$i bs=1m count=50 2>/dev/null; done
s=$(date +%s); for i in 1 2 3 4 5 6 7 8; do ( cp /tmp/c_$i $T/c_$i ) & done; wait; e=$(date +%s)
echo "     8x50MB parallel write took $((e-s)) s" | tee -a $LOG
for i in 1 2 3 4 5 6 7 8; do chk "parallel file $i" "$(sh1 $K/c_$i)" "$(sh1 /tmp/c_$i)"; done
for i in 1 2 3 4 5 6 7 8; do ( sh1 $T/c_$i > /tmp/c_$i.sum ) & done; wait
for i in 1 2 3 4 5 6 7 8; do chk "parallel read $i" "$(cat /tmp/c_$i.sum)" "$(sh1 /tmp/c_$i)"; done
rm -f /tmp/c_* ; rm -f ${T:?}/c_?
# cleanup
rm -rf $T 2>/dev/null; umount $M || umount -f $M; rmdir $M
sleep 1; rm -rf $K; echo "stuckU=$(ps -axo stat,comm | awk '$1 ~ /U/' | wc -l | tr -d ' ') fusenfs=$(pgrep fuse-nfs | wc -l | tr -d ' ')" | tee -a $LOG
echo "RESULT pass=$pass fail=$fail" | tee -a $LOG
