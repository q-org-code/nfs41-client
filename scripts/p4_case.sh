#!/bin/zsh
# usage: p4_case.sh <name> <url-options>   Phase 4: fuse-nfs on fuse-t via .213, NAS blocked 60 s.
R=$HOME/Developer/nfs41-client; name=$1; opts=$2; IP=192.168.50.213
d=$R/build/mnt_$name; O=$R/docs/phase4; L=$O/$name.log; : > $L; mkdir -p $d
dd if=/dev/urandom of=/Volumes/REF/.p4_testfile bs=1m count=1 2>/dev/null
$R/build/fuse-nfs/fuse-nfs -n "nfs://$IP/REF?version=4.1&$opts" -m $d > $O/$name.fuse.log 2>&1 &
sleep 6; mount | grep -c "mnt_$name" >> $L
f=$d/.p4_testfile
( while :; do s=$(date +%s); stat -f %z $f >/dev/null 2>&1; rc=$?; e=$(date +%s); echo "$e READ rc=$rc dur=$((e-s))s" >> $L; sleep 1; done ) &
RP=$!
( while :; do echo "$(date +%s) OBS stuckU=$(ps -axo stat,comm | awk '$1 ~ /U/' | wc -l | tr -d ' ') mounted=$(mount | grep -c mnt_$name) fusenfs=$(pgrep -c fuse-nfs 2>/dev/null || pgrep fuse-nfs | wc -l | tr -d " ")" >> $L; sleep 1; done ) &
OP=$!
sleep 10
echo "$(date +%s) FAULT-START" >> $L
osascript -e "do shell script \"/bin/sh $R/scripts/fault.sh 60 > $O/$name.fault 2>&1\" with administrator privileges" >> $L 2>&1
echo "$(date +%s) FAULT-END" >> $L
sleep 40
kill $RP $OP 2>/dev/null; wait 2>/dev/null
umount $d >> $L 2>&1 || umount -f $d >> $L 2>&1; rmdir $d 2>/dev/null
rm -f /Volumes/REF/.p4_testfile
echo "$(date +%s) DONE mounted=$(mount | grep -c mnt_$name) fusenfs=$(pgrep -c fuse-nfs 2>/dev/null || pgrep fuse-nfs | wc -l | tr -d " ")" >> $L
