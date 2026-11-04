#!/usr/bin/env python3
"""Serve the self-contained browser build on loopback only."""
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import argparse

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--port',type=int,default=8771)
args=parser.parse_args()
if not (root/'build/web/index.html').exists(): parser.error('Build the core and UI first')
server=ThreadingHTTPServer(('127.0.0.1',args.port),partial(SimpleHTTPRequestHandler,directory=str(root/'build/web')))
print(f'Orcs & Elves II — BREW: http://127.0.0.1:{args.port}/',flush=True)
try: server.serve_forever()
except KeyboardInterrupt: pass
finally: server.server_close()
