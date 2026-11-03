#!/usr/bin/env python3
"""Serve the standalone Godot Web export locally and open it in the browser."""
import argparse
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import webbrowser

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8767)
args = parser.parse_args()
if not (root/'build/web/index.html').exists():
    parser.error('Сначала собери Web: Godot --headless --path game --export-release Web')
try:
    server = ThreadingHTTPServer(('127.0.0.1', args.port),
                                 partial(SimpleHTTPRequestHandler, directory=str(root/'build/web')))
except OSError:
    parser.error('Порт занят. Укажи другой через --port.')
url = f'http://127.0.0.1:{args.port}/'
print(f'Orcs & Elves II: {url}\nОставь это окно открытым во время игры.', flush=True)
webbrowser.open(url)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
