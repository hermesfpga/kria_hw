SUMMARY = "Custom FPGA bitstream & generated device tree"
LICENSE = "CLOSED"
SRC_URI = " \
    file://hermes-autoexpand-rootfs.sh \
    file://hermes-autoexpand-rootfs.service \
    file://hermes-load-bitstream.sh \
    file://hermes-load-bitstream.service \
    file://hermes-load-overlay.sh \
"

inherit allarch systemd

# Boot-safe default: expand rootfs automatically, but do not auto-load PL
# bitstream/overlay until hardware path is validated.
SYSTEMD_SERVICE:${PN} = "hermes-autoexpand-rootfs.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += " \
    coreutils \
    devmem2 \
    dtc \
    e2fsprogs-resize2fs \
    parted \
    procps \
    util-linux \
"

# Optional explicit bitstream filename from /dt (e.g. "kria_zynq.bit").
# If empty, recipe requires exactly one .bit in /dt.
HERMES_EXTERNAL_BIT ?= ""

# Optional runtime loader alias under /lib/firmware (e.g. "default.bit").
# When set, a symlink with this name points to the installed selected bitstream.
HERMES_FIRMWARE_ALIAS ?= ""

# dfx-mgr default accelerator package name written to /etc/dfx-mgrd/default_firmware.
HERMES_DEFAULT_ACCEL ?= "hermes-custom"

do_install () {
    bbnote "Installing FPGA artifacts from /dt"
    ls -la /dt || bbwarn "No /dt directory found"

    SELECTED_BIT="${HERMES_EXTERNAL_BIT}"
    if [ -n "${SELECTED_BIT}" ]; then
        if [ ! -f "/dt/${SELECTED_BIT}" ]; then
            bbfatal "Requested bitstream not found: /dt/${SELECTED_BIT}"
        fi
        SELECTED_BIT_PATH="/dt/${SELECTED_BIT}"
    else
        BIT_CANDIDATES=$(find /dt -maxdepth 1 -type f -name "*.bit" | sort)
        BIT_COUNT=$(printf '%s\n' "${BIT_CANDIDATES}" | sed '/^$/d' | wc -l)
        if [ "${BIT_COUNT}" -ne 1 ]; then
            bbfatal "Expected exactly one .bit in /dt when HERMES_EXTERNAL_BIT is unset, found ${BIT_COUNT}"
        fi
        SELECTED_BIT_PATH=$(printf '%s\n' "${BIT_CANDIDATES}" | head -1)
        SELECTED_BIT=$(basename "${SELECTED_BIT_PATH}")
    fi

    install -d ${D}${nonarch_base_libdir}/firmware
    install -m 0644 "${SELECTED_BIT_PATH}" "${D}${nonarch_base_libdir}/firmware/${SELECTED_BIT}"

    if [ -n "${HERMES_FIRMWARE_ALIAS}" ]; then
        ln -sf "${SELECTED_BIT}" "${D}${nonarch_base_libdir}/firmware/${HERMES_FIRMWARE_ALIAS}"
        bbnote "Created firmware alias ${HERMES_FIRMWARE_ALIAS} -> ${SELECTED_BIT}"
    fi

    install -d ${D}/boot/dtbs
    install -m 0644 /dt/*.dtb ${D}/boot/dtbs/ 2>/dev/null || bbwarn "No .dtb files found in /dt"
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/hermes-autoexpand-rootfs.sh ${D}${sbindir}/hermes-autoexpand-rootfs
    install -m 0755 ${WORKDIR}/hermes-load-bitstream.sh ${D}${sbindir}/hermes-load-bitstream
    install -m 0755 ${WORKDIR}/hermes-load-overlay.sh ${D}${sbindir}/hermes-load-overlay
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/hermes-autoexpand-rootfs.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/hermes-load-bitstream.service ${D}${systemd_system_unitdir}/
    install -d ${D}${sysconfdir}/hermes
    printf '%s\n' "${SELECTED_BIT}" > ${D}${sysconfdir}/hermes/bitstream-firmware
    install -d ${D}${nonarch_base_libdir}/firmware
    if [ ! -f "/dt/pl-overlay.dts" ]; then
        bbfatal "Required overlay source missing: /dt/pl-overlay.dts (must match generated bitstream)"
    fi
    install -m 0644 /dt/pl-overlay.dts ${D}${nonarch_base_libdir}/firmware/pl-overlay.dts
    bbnote "Installed pl-overlay.dts from /dt for runtime device tree overlay support"
    install -d ${D}${sysconfdir}/dfx-mgrd
    ln -sf "${nonarch_base_libdir}/firmware/${SELECTED_BIT}" "${D}${sysconfdir}/dfx-mgrd/default_firmware"
    printf '%s\n' "${HERMES_DEFAULT_ACCEL}" > ${D}${sysconfdir}/dfx-mgrd/${HERMES_DEFAULT_ACCEL}
    bbnote "Installed files:"
    find ${D}${nonarch_base_libdir}/firmware -name "*.bit" -exec basename {} \; || true
    find ${D}/boot/dtbs -name "*.dtb" -exec basename {} \; || true
}

FILES:${PN} += " \
    ${nonarch_base_libdir}/firmware/* \
    /boot/dtbs/* \
    ${sbindir}/hermes-autoexpand-rootfs \
    ${sbindir}/hermes-load-bitstream \
    ${sbindir}/hermes-load-overlay \
    ${sysconfdir}/hermes/bitstream-firmware \
    ${sysconfdir}/dfx-mgrd/default_firmware \
    ${systemd_system_unitdir}/hermes-autoexpand-rootfs.service \
    ${systemd_system_unitdir}/hermes-load-bitstream.service \
"
