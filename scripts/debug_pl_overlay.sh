#!/bin/sh
set -eu

echo "=== A: boot context ==="
uname -a
cat /proc/cmdline
ls -l /boot/system.dtb /boot/dtbs 2>/dev/null || true
if command -v file >/dev/null 2>&1; then
    file /boot/system.dtb || true
fi
dtc -I dtb -O dts -o /tmp/base.dts /boot/system.dtb
grep -nE "axi_timer_0|80010000|amba|misc_clk_0|__symbols__" /tmp/base.dts | head -n 80 || true

echo "=== B: live DT symbols ==="
ls -l /sys/firmware/devicetree/base/__symbols__ 2>/dev/null || echo "NO __symbols__"
ls /sys/firmware/devicetree/base/__symbols__ 2>/dev/null | grep -E "amba|misc_clk_0|axi" || true
if [ -r /sys/firmware/devicetree/base/model ]; then
    tr -d '\000' < /sys/firmware/devicetree/base/model
    echo
fi

echo "=== C: fpga manager + firmware ==="
cat /sys/class/fpga_manager/fpga0/state
cat /etc/hermes/bitstream-firmware
BIT="$(tr -d " \t\r\n" < /etc/hermes/bitstream-firmware)"
echo "BIT=$BIT"
ls -l "/lib/firmware/$BIT"
if command -v md5sum >/dev/null 2>&1; then
    md5sum "/lib/firmware/$BIT"
fi

echo "=== D: overlay source + compile ==="
ls -l /lib/firmware/pl-overlay.dts
sed -n '1,160p' /lib/firmware/pl-overlay.dts
if dtc -@ -q -I dts -O dtb -i /sys/firmware/devicetree/base -o /tmp/pl-overlay.dtbo /lib/firmware/pl-overlay.dts; then
    echo "DTC_RC=0"
else
    rc=$?
    echo "DTC_RC=$rc"
    exit "$rc"
fi
ls -l /tmp/pl-overlay.dtbo

echo "=== E: overlay apply ==="
mount -t configfs none /sys/kernel/config 2>/dev/null || true
rm -rf /sys/kernel/config/device-tree/overlays/pl-overlay 2>/dev/null || true
mkdir -p /sys/kernel/config/device-tree/overlays/pl-overlay
if cat /tmp/pl-overlay.dtbo > /sys/kernel/config/device-tree/overlays/pl-overlay/dtbo; then
    echo "APPLY_RC=0"
else
    rc=$?
    echo "APPLY_RC=$rc"
fi
cat /sys/kernel/config/device-tree/overlays/pl-overlay/status 2>/dev/null || true
dmesg | tail -n 120
grep -r 80010000 /proc/device-tree/ || true
ls /proc/device-tree/*/axi_timer_0 2>/dev/null || true

echo "=== F: safe devmem probe ==="
if command -v timeout >/dev/null 2>&1; then
    if timeout 2 devmem2 0x80010000; then
        echo "DEVMEM_RC=0"
    else
        rc=$?
        echo "DEVMEM_RC=$rc"
    fi
else
    echo "timeout not found; skipping raw devmem2 to avoid freeze"
fi
