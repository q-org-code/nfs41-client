#!/bin/sh
# root: block outbound TCP to one NAS address for $1 seconds, always restore.
IP=192.168.50.213; DUR=${1:-60}; A=com.apple/claude_phase0
pfctl -s info 2>&1 | head -1
TOKEN=$(pfctl -E 2>&1 | awk '/Token/{print $NF}')
cleanup(){ pfctl -a "$A" -F all >/dev/null 2>&1; [ -n "$TOKEN" ] && pfctl -X "$TOKEN" >/dev/null 2>&1; echo "restored $(date +%T)"; }
trap cleanup EXIT INT TERM HUP
pfctl -sr 2>/dev/null | grep -q 'anchor "com.apple/\*"' || pfctl -f /etc/pf.conf 2>&1 | head -2
echo "block drop out quick proto tcp to $IP" | pfctl -a "$A" -f - 2>&1 | head -3
pfctl -a "$A" -sr 2>&1 | head -3
pfctl -k 0.0.0.0/0 -k $IP 2>&1 | head -2
echo "blocked $(date +%T)"
sleep "$DUR"
