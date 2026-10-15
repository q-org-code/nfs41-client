#!/usr/bin/env python3 -I
"""TCP proxy for fault tests. Usage: faultproxy.py LISTEN_PORT TARGET_IP [TARGET_PORT]
Control by file: touch /tmp/fp_block -> new bytes are black-holed and new connections are
held; remove it -> traffic flows again. Existing sockets stay open while blocked (like a
dead NAS behind pf 'block drop')."""
import socket, threading, os, sys, time
lp, ip = int(sys.argv[1]), sys.argv[2]; tp = int(sys.argv[3]) if len(sys.argv) > 3 else 2049
blocked = lambda: os.path.exists("/tmp/fp_block")
def pump(a, b):
    try:
        while True:
            d = a.recv(65536)
            if not d: break
            while blocked(): time.sleep(0.1)   # hold data: nothing reaches the peer
            b.sendall(d)
    except OSError: pass
    for s in (a, b):
        try: s.close()
        except OSError: pass
srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", lp)); srv.listen(16)
while True:
    c, _ = srv.accept()
    while blocked(): time.sleep(0.1)
    u = socket.create_connection((ip, tp))
    threading.Thread(target=pump, args=(c, u), daemon=True).start()
    threading.Thread(target=pump, args=(u, c), daemon=True).start()
