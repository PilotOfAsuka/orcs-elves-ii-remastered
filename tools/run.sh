#!/bin/sh
set -eu
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$PROJECT_ROOT/build"
if [ -n "${GODOT_BIN:-}" ]; then
    ENGINE="$GODOT_BIN"
elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    ENGINE=/Applications/Godot.app/Contents/MacOS/Godot
elif command -v godot >/dev/null 2>&1; then
    ENGINE=$(command -v godot)
else
    echo 'Для запуска нужен Godot 4.7.2. Можно указать путь через GODOT_BIN.'
    exit 1
fi
"$ENGINE" --headless --path "$PROJECT_ROOT/game" --editor --import --quit > "$PROJECT_ROOT/build/import.log" 2>&1
exec "$ENGINE" --path "$PROJECT_ROOT/game" "$@"
