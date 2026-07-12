#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo ./test_overlay_live.sh" >&2
    exit 1
fi

echo "=== 1) Prep mounts ==="
mount -o remount,rw / || true
mount -t configfs none /sys/kernel/config 2>/dev/null || true

echo "=== 2) Check overlay source ==="
if [ ! -f /lib/firmware/pl-overlay.dts ]; then
    echo "Missing /lib/firmware/pl-overlay.dts" >&2
    exit 1
fi
ls -l /lib/firmware/pl-overlay.dts

echo "=== 3) Backup and patch overlay source (remove misc_clk_0 refs) ==="
cp -a /lib/firmware/pl-overlay.dts /lib/firmware/pl-overlay.dts.bak.$(date +%Y%m%d%H%M%S)
# Remove clock bindings that rely on symbols not present on base KR260 DT.
sed -i '/misc_clk_0/d;/clock-names = "s_axi_aclk"/d' /lib/firmware/pl-overlay.dts

echo "=== 4) Compile overlay to writable runtime dir ==="
mkdir -p /run/hermes-overlay
if dtc -@ -q -I dts -O dtb -i /sys/firmware/devicetree/base -o /run/hermes-overlay/pl-overlay.dtbo /lib/firmware/pl-overlay.dts; then
    echo "Compile OK"
else
    rc=$?
    echo "Compile failed (rc=$rc)" >&2
    exit "$rc"
fi
ls -l /run/hermes-overlay/pl-overlay.dtbo

echo "=== 5) Apply overlay ==="
rm -rf /sys/kernel/config/device-tree/overlays/pl-overlay 2>/dev/null || true
mkdir -p /sys/kernel/config/device-tree/overlays/pl-overlay
cat /run/hermes-overlay/pl-overlay.dtbo > /sys/kernel/config/device-tree/overlays/pl-overlay/dtbo

echo "=== 6) Verify overlay status and live DT ==="
cat /sys/kernel/config/device-tree/overlays/pl-overlay/status
echo "--- /proc/device-tree match ---"
grep -r 80010000 /proc/device-tree/ || true
ls /proc/device-tree/*/axi_timer_0 2>/dev/null || true

echo "=== 7) Safe register probe ==="
if command -v timeout >/dev/null 2>&1; then
    timeout 2 devmem2 0x80010000 || true
else
    echo "timeout not found; skipping devmem2 to avoid hard freeze"
fi

echo "=== done ==="
