#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <bitstream.bit> <design.xsa>" >&2
    exit 2
fi

BIT_FILE="$1"
XSA_FILE="$2"

if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN=python
else
    echo "python3 or python is required" >&2
    exit 127
fi

if [ ! -f "$BIT_FILE" ]; then
    echo "Missing bitstream: $BIT_FILE" >&2
    exit 1
fi

if [ ! -s "$BIT_FILE" ]; then
    echo "Bitstream is empty: $BIT_FILE" >&2
    exit 1
fi

if [ ! -f "$XSA_FILE" ]; then
    echo "Missing XSA: $XSA_FILE" >&2
    exit 1
fi

if ! "$PYTHON_BIN" - "$XSA_FILE" <<'PY'
import sys
import zipfile
path = sys.argv[1]
with zipfile.ZipFile(path) as zf:
    if not zf.namelist():
        raise SystemExit('XSA archive is empty')
PY
then
    echo "Invalid XSA archive: $XSA_FILE" >&2
    exit 1
fi

if ! "$PYTHON_BIN" - "$BIT_FILE" <<'PY'
import sys
path = sys.argv[1]
with open(path, 'rb') as handle:
    sample = handle.read(64)
if not sample:
    raise SystemExit(1)
PY
then
    echo "Bitstream could not be read as a regular file: $BIT_FILE" >&2
    exit 1
fi

echo "Validated bitstream and XSA artifacts"
