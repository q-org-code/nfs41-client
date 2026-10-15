#!/bin/zsh
# usage: case.sh <name> <extra mount opts>
B=/private/tmp/claude-501/-Users-quasaur/2319ebf1-75b6-4ee6-aedc-826c122370b1/scratchpad/p0
name=$1; opts=$2; IP=192.168.50.213
d=$B/mnt_$name; mkdir -p $d; L=$B/$name.log; : > $L
mount_nfs -o vers=4.1,noresvport,ro,noac,$opts $IP:/REF $d >> $L 2>&1 || { echo "mount failed" >> $L; exit 1; }
f=$d/.claude_phase0_testfile
nfsstat -m | grep -A4 "mnt_$name" | grep -i "NFS parameters" >> $L
( while :; do s=$(date +%s); stat -f %z $f >/dev/null 2>&1; rc=$?; e=$(date +%s); echo "$e READ rc=$rc dur=$((e-s))s" >> $L; sleep 1; done ) &
RP=$!
( while :; do echo "$(date +%s) OBS stuckU=$(ps -axo stat,comm | awk '$1 ~ /U/ && $2 ~ /stat$/' | wc -l | tr -d ' ') mounted=$(mount | grep -c mnt_$name)" >> $L; sleep 1; done ) &
OP=$!
sleep 10
echo "$(date +%s) FAULT-START" >> $L
osascript -e "do shell script \"/bin/sh $B/fault.sh 60 > $B/$name.fault 2>&1\" with administrator privileges" >> $L 2>&1
echo "$(date +%s) FAULT-END" >> $L
sleep 40
kill $RP $OP 2>/dev/null; wait 2>/dev/null
umount -f $d >> $L 2>&1; rmdir $d 2>/dev/null
echo "$(date +%s) DONE mounted=$(mount | grep -c mnt_$name)" >> $L
