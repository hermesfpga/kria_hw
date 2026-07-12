#!/bin/sh
set -eu

# HERMES_ROOT: optional prefix for all system paths. Set in unit tests to redirect
# sysfs, firmware, and config paths to a temporary mock root. Defaults to empty.
HERMES_ROOT="${HERMES_ROOT:-}"

# HERMES_OVERLAY_LOADER: path to overlay loader binary. Override in tests to inject a mock.
HERMES_OVERLAY_LOADER="${HERMES_OVERLAY_LOADER:-/usr/sbin/hermes-load-overlay}"

FW_FILE="${HERMES_ROOT}/etc/hermes/bitstream-firmware"
FPGA_FLAGS="${HERMES_ROOT}/sys/class/fpga_manager/fpga0/flags"
FPGA_FW="${HERMES_ROOT}/sys/class/fpga_manager/fpga0/firmware"
FPGA_STATE="${HERMES_ROOT}/sys/class/fpga_manager/fpga0/state"

if [ ! -f "$FW_FILE" ]; then
    echo "hermes-load-bitstream: missing $FW_FILE" >&2
    exit 1
fi

BIT_NAME="$(cat "$FW_FILE")"
BIT_NAME="${BIT_NAME%%[[:space:]]*}"
BIT_NAME="$(basename "$BIT_NAME")"

if [ -z "$BIT_NAME" ]; then
    echo "hermes-load-bitstream: empty bitstream name in $FW_FILE" >&2
    exit 1
fi

if [ ! -f "${HERMES_ROOT}/lib/firmware/$BIT_NAME" ]; then
    echo "hermes-load-bitstream: ${HERMES_ROOT}/lib/firmware/$BIT_NAME not found" >&2
    exit 1
fi

if [ ! -w "$FPGA_FW" ]; then
    echo "hermes-load-bitstream: fpga manager firmware node not writable" >&2
    exit 1
fi

# Full configuration load mode.
echo 0 > "$FPGA_FLAGS"
echo "$BIT_NAME" > "$FPGA_FW"

if [ -r "$FPGA_STATE" ]; then
    STATE="$(cat "$FPGA_STATE")"
    echo "hermes-load-bitstream: fpga0 state=$STATE"
    case "$STATE" in
        operating)
            # Bitstream loaded successfully, now update device tree
            echo "hermes-load-bitstream: loading programmable logic device tree overlay..."
            if ! "${HERMES_OVERLAY_LOADER}" "pl-overlay"; then
                echo "hermes-load-bitstream: device tree overlay load failed" >&2
                echo "hermes-load-bitstream: refusing to continue with mismatched PL/device-tree state" >&2
                exit 1
            fi
            exit 0
            ;;
        *)
            echo "hermes-load-bitstream: unexpected fpga0 state '$STATE'" >&2
            exit 1
            ;;
    esac
fi

exit 0
