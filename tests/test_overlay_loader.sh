#!/bin/sh
# Tests for hermes-load-overlay.sh
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/tests/lib/assert.sh"
. "$REPO_ROOT/tests/lib/mock_env.sh"

SCRIPT="$REPO_ROOT/yocto/meta-custom-bitstream/recipes-bsp/kria-artifacts/files/hermes-load-overlay.sh"
OVERLAY_DTS="$REPO_ROOT/dt_example/dt/pl-overlay.dts"

# Ensure cleanup even on unexpected exit
trap 'teardown_mock_root 2>/dev/null; true' EXIT

echo "=== test_overlay_loader ==="
echo ""

# --- Test 1: .dts missing from firmware dir ---
test_case "error: .dts not found in firmware dir"
setup_mock_root
# deliberately do NOT place pl-overlay.dts
assert_exit_nonzero env HERMES_ROOT="$MOCK_ROOT" sh "$SCRIPT" pl-overlay
teardown_mock_root

# --- Test 2: configfs not mounted ---
test_case "error: configfs overlays directory not present"
setup_mock_root
cp "$OVERLAY_DTS" "${MOCK_ROOT}/lib/firmware/pl-overlay.dts"
# Pre-create a fake .dtbo with an old .dts timestamp so compilation is skipped
touch -t 200001010000 "${MOCK_ROOT}/lib/firmware/pl-overlay.dts"
printf '\xd0\x0d\xfe\xed' > "${MOCK_ROOT}/lib/firmware/pl-overlay.dtbo"
# Remove configfs so the script hits "not mounted" error
rm -rf "${MOCK_ROOT}/sys/kernel/config"
assert_exit_nonzero env HERMES_ROOT="$MOCK_ROOT" sh "$SCRIPT" pl-overlay
teardown_mock_root

# --- Test 3: pl-overlay.dts compiles cleanly with dtc ---
test_case "dtc: pl-overlay.dts compiles to dtbo without errors (dtc required)"
if ! command -v dtc >/dev/null 2>&1; then
    echo "SKIP (dtc not in PATH)"
else
    _out=$(mktemp /tmp/hermes-test-dtbo-XXXXXX)
    assert_exit_zero dtc -@ -O dtb -o "$_out" "$OVERLAY_DTS"
    rm -f "$_out"
fi

# --- Test 4: happy path with dtc ---
test_case "happy path: compile .dts and load into mock configfs (dtc required)"
if ! command -v dtc >/dev/null 2>&1; then
    echo "SKIP (dtc not in PATH)"
else
    setup_mock_root
    cp "$OVERLAY_DTS" "${MOCK_ROOT}/lib/firmware/pl-overlay.dts"
    assert_exit_zero env HERMES_ROOT="$MOCK_ROOT" sh "$SCRIPT" pl-overlay
    teardown_mock_root
fi

# --- Test 5: .dtbo file is created on disk ---
test_case ".dtbo file created in firmware dir after compilation (dtc required)"
if ! command -v dtc >/dev/null 2>&1; then
    echo "SKIP (dtc not in PATH)"
else
    setup_mock_root
    cp "$OVERLAY_DTS" "${MOCK_ROOT}/lib/firmware/pl-overlay.dts"
    env HERMES_ROOT="$MOCK_ROOT" sh "$SCRIPT" pl-overlay >/dev/null 2>&1 || true
    assert_file_exists "${MOCK_ROOT}/lib/firmware/pl-overlay.dtbo"
    teardown_mock_root
fi

# --- Test 6: overlay directory created in mock configfs ---
test_case "overlay directory created under configfs overlays/ (dtc required)"
if ! command -v dtc >/dev/null 2>&1; then
    echo "SKIP (dtc not in PATH)"
else
    setup_mock_root
    cp "$OVERLAY_DTS" "${MOCK_ROOT}/lib/firmware/pl-overlay.dts"
    env HERMES_ROOT="$MOCK_ROOT" sh "$SCRIPT" pl-overlay >/dev/null 2>&1 || true
    assert_dir_exists "${MOCK_ROOT}/sys/kernel/config/device-tree/overlays/pl-overlay"
    teardown_mock_root
fi

test_suite_summary "test_overlay_loader"
all_passed
