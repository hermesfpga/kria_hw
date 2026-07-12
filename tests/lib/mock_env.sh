#!/bin/sh
# Mock environment helpers for hermes unit tests.
# Source this file; call setup_mock_root before each test, teardown_mock_root after.

MOCK_ROOT=""

setup_mock_root() {
    MOCK_ROOT=$(mktemp -d /tmp/hermes-test-XXXXXX)

    # fpga_manager sysfs nodes
    mkdir -p "${MOCK_ROOT}/sys/class/fpga_manager/fpga0"
    echo "0"         > "${MOCK_ROOT}/sys/class/fpga_manager/fpga0/flags"
    touch              "${MOCK_ROOT}/sys/class/fpga_manager/fpga0/firmware"
    echo "operating" > "${MOCK_ROOT}/sys/class/fpga_manager/fpga0/state"

    # configfs: device-tree overlays
    mkdir -p "${MOCK_ROOT}/sys/kernel/config/device-tree/overlays"

    # hermes runtime config
    mkdir -p "${MOCK_ROOT}/etc/hermes"

    # firmware directory (mirrors /lib/firmware on target)
    mkdir -p "${MOCK_ROOT}/lib/firmware"

    # mock overlay loader: records that it was called and exits 0
    mkdir -p "${MOCK_ROOT}/usr/sbin"
    printf '#!/bin/sh\necho "mock-overlay-loader: called with: $*" >&2\nexit 0\n' \
        > "${MOCK_ROOT}/usr/sbin/hermes-load-overlay"
    chmod +x "${MOCK_ROOT}/usr/sbin/hermes-load-overlay"

    export MOCK_ROOT
}

teardown_mock_root() {
    if [ -n "${MOCK_ROOT}" ] && [ -d "${MOCK_ROOT}" ]; then
        rm -rf "${MOCK_ROOT}"
    fi
    MOCK_ROOT=""
}
