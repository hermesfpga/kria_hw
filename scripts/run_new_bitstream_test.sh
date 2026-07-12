#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo ./run_new_bitstream_test.sh" >&2
    exit 1
fi

BIT_SRC="${1:-/boot/dtbs/kria_zynq2.bit}"
BIT_NAME="${2:-kria_zynq2.bit}"
OVERLAY_SRC="${3:-/boot/dtbs/pl-overlay.dts}"

echo "=== 1) confirm new bitstream exists ==="
ls -l "$BIT_SRC"

echo "=== 2) install it where fpga_manager expects ==="
cp -f "$BIT_SRC" "/lib/firmware/$BIT_NAME"
sync
ls -l "/lib/firmware/$BIT_NAME"
md5sum "$BIT_SRC" "/lib/firmware/$BIT_NAME"

echo "=== 2b) install matching overlay source when available ==="
if [ -f "$OVERLAY_SRC" ]; then
    cp -f "$OVERLAY_SRC" /lib/firmware/pl-overlay.dts
    sync
    ls -l /lib/firmware/pl-overlay.dts
    md5sum "$OVERLAY_SRC" /lib/firmware/pl-overlay.dts
else
    echo "warning: $OVERLAY_SRC not found; reusing existing /lib/firmware/pl-overlay.dts" >&2
fi

echo "=== 3) point Hermes loader to new bitstream ==="
echo "$BIT_NAME" > /etc/hermes/bitstream-firmware
cat /etc/hermes/bitstream-firmware

echo "=== 4) program FPGA ==="
echo 0 > /sys/class/fpga_manager/fpga0/flags
echo "$BIT_NAME" > /sys/class/fpga_manager/fpga0/firmware
cat /sys/class/fpga_manager/fpga0/state

echo "=== 5) ensure overlay dtbo exists ==="
mkdir -p /run/hermes-overlay
dtc -@ -q -I dts -O dtb -o /run/hermes-overlay/pl-overlay.dtbo /lib/firmware/pl-overlay.dts
ls -l /run/hermes-overlay/pl-overlay.dtbo

echo "=== 6) apply overlay ==="
mount -t configfs none /sys/kernel/config 2>/dev/null || true
rm -rf /sys/kernel/config/device-tree/overlays/pl-overlay 2>/dev/null || true
mkdir -p /sys/kernel/config/device-tree/overlays/pl-overlay
cat /run/hermes-overlay/pl-overlay.dtbo > /sys/kernel/config/device-tree/overlays/pl-overlay/dtbo
cat /sys/kernel/config/device-tree/overlays/pl-overlay/status

echo "=== 7) verify timer node exists ==="
find /proc/device-tree -name 'timer@80010000' 2>/dev/null || true
ls /sys/bus/platform/devices | grep 80010000 || true

echo "=== 8) safe probe (2s timeout) ==="
if command -v timeout >/dev/null 2>&1; then
    timeout 2 devmem2 0x80010000 || true
else
    echo "timeout not found; skipping devmem2 to avoid hard freeze"
fi
