#!/bin/sh
# root: capture traffic to/from one NAS address (tcpdump on its interface) while fault.sh blocks it. usage: fault_capture.sh <pcap-file> <seconds>
IP=192.168.50.213; OUT=$1; DUR=${2:-60}
IF=$(route get $IP 2>/dev/null | awk '/interface:/{print $2}')
tcpdump -i "${IF:-en5}" -n -U -w "$OUT" host $IP >/dev/null 2>&1 &
TP=$!
sleep 1
/bin/sh "$(dirname "$0")/fault.sh" "$DUR"
sleep 3
kill $TP 2>/dev/null; sleep 1; kill -0 $TP 2>/dev/null && kill -KILL $TP 2>/dev/null; wait $TP 2>/dev/null
chmod 644 "$OUT"
echo "pcap: $(ls -l "$OUT" | awk '{print $5}') bytes"
