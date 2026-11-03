#!/bin/sh
set -eu
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$PROJECT_ROOT/build"
exec "$PROJECT_ROOT/tools/run.sh"
