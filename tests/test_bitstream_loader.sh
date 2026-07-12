#!/bin/sh
# Tests for hermes-load-bitstream.sh
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/tests/lib/assert.sh"
. "$REPO_ROOT/tests/lib/mock_env.sh"

SCRIPT="$REPO_ROOT/yocto/meta-custom-bitstream/recipes-bsp/kria-artifacts/files/hermes-load-bitstream.sh"

# Ensure cleanup even on unexpected exit
trap 'teardown_mock_root 2>/dev/null; true' EXIT

echo "=== test_bitstream_loader ==="
echo ""

# --- Test 1: happy path ---
test_case "happy path: valid env, fpga state=operating"
setup_mock_root
echo "test.bit" > "${MOCK_ROOT}/etc/hermes/bitstream-firmware"
touch "${MOCK_ROOT}/lib/firmware/test.bit"
assert_exit_zero env \
    HERMES_ROOT="$MOCK_ROOT" \
    HERMES_OVERLAY_LOADER="${MOCK_ROOT}/usr/sbin/hermes-load-overlay" \
    sh "$SCRIPT"
teardown_mock_root

# --- Test 2: missing bitstream-firmware config ---
test_case "error: bitstream-firmware config file missing"
setup_mock_root
# deliberately do NOT create the FW_FILE
assert_exit_nonzero env \
    HERMES_ROOT="$MOCK_ROOT" \
    HERMES_OVERLAY_LOADER="${MOCK_ROOT}/usr/sbin/hermes-load-overlay" \
    sh "$SCRIPT"
teardown_mock_root

# --- Test 3: .bit file absent from firmware dir ---
test_case "error: .bit file not present in /lib/firmware"
setup_mock_root
echo "missing.bit" > "${MOCK_ROOT}/etc/hermes/bitstream-firmware"
# deliberately do NOT create the .bit file
assert_exit_nonzero env \
    HERMES_ROOT="$MOCK_ROOT" \
    HERMES_OVERLAY_LOADER="${MOCK_ROOT}/usr/sbin/hermes-load-overlay" \
    sh "$SCRIPT"
teardown_mock_root

# --- Test 4: fpga state is not 'operating' ---
test_case "error: fpga state=programming_error"
setup_mock_root
echo "test.bit" > "${MOCK_ROOT}/etc/hermes/bitstream-firmware"
touch "${MOCK_ROOT}/lib/firmware/test.bit"
echo "programming_error" > "${MOCK_ROOT}/sys/class/fpga_manager/fpga0/state"
assert_exit_nonzero env \
    HERMES_ROOT="$MOCK_ROOT" \
    HERMES_OVERLAY_LOADER="${MOCK_ROOT}/usr/sbin/hermes-load-overlay" \
    sh "$SCRIPT"
teardown_mock_root

# --- Test 5: correct bitstream name is written to fpga_manager firmware node ---
test_case "fpga firmware sysfs written with correct bitstream name"
setup_mock_root
echo "mydesign.bit" > "${MOCK_ROOT}/etc/hermes/bitstream-firmware"
touch "${MOCK_ROOT}/lib/firmware/mydesign.bit"
env HERMES_ROOT="$MOCK_ROOT" \
    HERMES_OVERLAY_LOADER="${MOCK_ROOT}/usr/sbin/hermes-load-overlay" \
    sh "$SCRIPT" >/dev/null 2>&1 || true
assert_file_contains "${MOCK_ROOT}/sys/class/fpga_manager/fpga0/firmware" "mydesign.bit"
teardown_mock_root

# --- Test 6: full path in config is normalized to a basename before loading ---
test_case "full path in config is normalized to basename"
setup_mock_root
echo "/lib/firmware/mydesign.bit" > "${MOCK_ROOT}/etc/hermes/bitstream-firmware"
touch "${MOCK_ROOT}/lib/firmware/mydesign.bit"
assert_exit_zero env \
    HERMES_ROOT="$MOCK_ROOT" \
    HERMES_OVERLAY_LOADER="${MOCK_ROOT}/usr/sbin/hermes-load-overlay" \
    sh "$SCRIPT"
assert_file_contains "${MOCK_ROOT}/sys/class/fpga_manager/fpga0/firmware" "mydesign.bit"
teardown_mock_root

# --- Test 7: overlay loader is invoked after successful bitstream load ---
test_case "overlay loader is invoked after successful bitstream load"
setup_mock_root
echo "test.bit" > "${MOCK_ROOT}/etc/hermes/bitstream-firmware"
touch "${MOCK_ROOT}/lib/firmware/test.bit"
OVERLAY_LOG="${MOCK_ROOT}/overlay-loader.log"
printf '#!/bin/sh\necho "called: $*" >> "%s"\nexit 0\n' "$OVERLAY_LOG" \
    > "${MOCK_ROOT}/usr/sbin/hermes-load-overlay"
chmod +x "${MOCK_ROOT}/usr/sbin/hermes-load-overlay"
env HERMES_ROOT="$MOCK_ROOT" \
    HERMES_OVERLAY_LOADER="${MOCK_ROOT}/usr/sbin/hermes-load-overlay" \
    sh "$SCRIPT" >/dev/null 2>&1 || true
assert_file_exists "$OVERLAY_LOG"
teardown_mock_root

test_suite_summary "test_bitstream_loader"
all_passed
