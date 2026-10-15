#!/bin/zsh
# usage: p5_write_outage.sh   Writes during an outage: fuse-nfs on scratch share REF, NAS address .213 blocked 60 s (root dialog).
# A: append one numbered line per second. B: a 20 MB copy started 10 s into the outage, then retried after recovery.
R=$HOME/Developer/nfs41-client; IP=192.168.50.213; FN=${FUSE_NFS:-$R/build/fuse-nfs/fuse-nfs}
OPTS=${NFS_OPTS:-}; M=$R/build/mnt_w; K=/Volumes/REF/.nfs41_w; O=$R/docs/phase5_write_outage; L=$O.log; : > $L; rm -f $O.fault; mkdir -p $M $K
now() { date +%s; }
$FN -n "nfs://$IP/REF?version=4.1&timeo=100&retrans=0&autoreconnect=-1&tcp-syncnt=2$OPTS" -m $M $FN_ARGS > $R/build/w.fuse.log 2>&1 &
sleep 6; mount | grep -q mnt_w || { echo "mount failed" | tee -a $L; exit 1; }
T=$M/.nfs41_w; mkdir -p $T; dd if=/dev/urandom of=/tmp/w_big bs=1m count=20 2>/dev/null; want=$(shasum -a 256 /tmp/w_big | cut -d' ' -f1)
( n=0; while :; do n=$((n+1)); s=$(now); printf 'line %06d\n' $n >> $T/append.txt 2>/dev/null; rc=$?; echo "$(now) A n=$n rc=$rc dur=$(( $(now)-s ))s" >> $L; sleep 1; done ) & AP=$!
( while :; do echo "$(now) OBS stuckU=$(ps -axo stat,comm | awk '$1 ~ /U/' | wc -l | tr -d ' ') mounted=$(mount | grep -c mnt_w)" >> $L; sleep 1; done ) & OP=$!
sleep 10; echo "$(now) FAULT-START (dialog)" >> $L
( while ! grep -q '^blocked' $O.fault 2>/dev/null; do sleep 0.5; done; echo "$(now) BLOCK-START" >> $L; sleep 10; s=$(now); cp /tmp/w_big $T/big_during 2>>$L; rc=$?; echo "$(now) B cp-during rc=$rc dur=$(( $(now)-s ))s" >> $L ) & CP=$!
FAULT=${FAULT_CMD:-"/bin/sh $R/scripts/fault.sh 60"}
osascript -e "do shell script \"$FAULT > $O.fault 2>&1\" with administrator privileges" >> $L 2>&1
echo "$(now) FAULT-END" >> $L
sleep 40; kill $AP $OP 2>/dev/null; wait $AP $OP $CP 2>/dev/null
rm -f $T/big_during; s=$(now); cp /tmp/w_big $T/big_after 2>>$L; rc=$?; echo "$(now) B cp-after rc=$rc dur=$(( $(now)-s ))s" >> $L
[ $rc -ne 0 ] && { sleep 10; rm -f $T/big_after; s=$(now); cp /tmp/w_big $T/big_after 2>>$L; rc=$?; echo "$(now) B cp-after-retry rc=$rc dur=$(( $(now)-s ))s" >> $L; }
sleep 3
echo "RESULT big_after sha ok: $([ "$(shasum -a 256 $K/big_after | cut -d' ' -f1)" = "$want" ] && echo yes || echo NO)" | tee -a $L
echo "RESULT append: lines=$(wc -l < $T/append.txt | tr -d ' ') well-formed=$(grep -c -E '^line [0-9]{6}$' $T/append.txt) garbled=$(grep -c -v -E '^line [0-9]{6}$' $T/append.txt)" | tee -a $L
echo "RESULT A: ok=$(grep -c ' A .* rc=0 ' $L) err=$(grep ' A ' $L | grep -vc 'rc=0 ') maxdur=$(grep ' A ' $L | sed -E 's/.*dur=([0-9]+)s/\1/' | sort -n | tail -1)s" | tee -a $L
echo "RESULT maxStuckU=$(grep OBS $L | sed -E 's/.*stuckU=([0-9]+).*/\1/' | sort -n | tail -1)" | tee -a $L
cp $T/append.txt $O.append.txt 2>/dev/null
rm -rf "${T:?}"; umount $M || umount -f $M; rmdir $M; sleep 1; rm -rf "${K:?}"; rm -f /tmp/w_big
