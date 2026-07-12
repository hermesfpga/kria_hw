#!/bin/sh
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'fake-bitstream-data' > "$TMP_DIR/kria_zynq.bit"
python3 - "$TMP_DIR/kria_zynq.xsa" <<'PY'
import sys
import zipfile
path = sys.argv[1]
with zipfile.ZipFile(path, 'w') as zf:
    zf.writestr('design.bit', b'fake-bitstream-data')
PY

"$REPO_ROOT/scripts/validate_vivado_artifacts.sh" "$TMP_DIR/kria_zynq.bit" "$TMP_DIR/kria_zynq.xsa"
