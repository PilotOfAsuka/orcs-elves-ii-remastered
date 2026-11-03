#!/usr/bin/env python3
"""Serve the standalone Godot Web export locally and open it in the browser."""
import argparse
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import webbrowser
from urllib.request import urlopen

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8767)
parser.add_argument('--no-open', action='store_true', help='Проверка сервера без открытия браузера')
args = parser.parse_args()
if not (root/'build/web/index.html').exists():
    parser.error('Сначала собери Web: Godot --headless --path game --export-release Web')
url = f'http://127.0.0.1:{args.port}/'
try:
    server = ThreadingHTTPServer(('127.0.0.1', args.port),
                                 partial(SimpleHTTPRequestHandler, directory=str(root/'build/web')))
except OSError:
    # Reuse this project's already-running preview instead of failing the launcher.
    matches = False
    try:
        with urlopen(url, timeout=2) as response:
            matches = response.read() == (root/'build/web/index.html').read_bytes()
    except OSError:
        pass
    if matches:
        print(f'Игра уже запущена: {url}', flush=True)
        if not args.no_open:
            webbrowser.open(url)
        raise SystemExit(0)
    parser.error('Порт занят. Укажи другой через --port.')
print(f'Orcs & Elves II: {url}\nОставь это окно открытым во время игры.', flush=True)
if not args.no_open:
    webbrowser.open(url)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
