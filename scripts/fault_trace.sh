#!/bin/sh
# root: fault_capture.sh plus an fs_usage trace of file-system calls on the test mount, to identify stray processes. usage: fault_trace.sh <pcap-file> <seconds> <trace-file>
D=$(dirname "$0"); PC=$1; DUR=${2:-60}; TR=$3
fs_usage -w -f filesys > "$TR" 2>&1 &
FP=$!
/bin/sh "$D/fault_capture.sh" "$PC" "$DUR"
sleep 25
kill $FP 2>/dev/null; sleep 1; kill -0 $FP 2>/dev/null && kill -KILL $FP 2>/dev/null
chmod 644 "$TR"
