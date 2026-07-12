SUMMARY = "Import external per-run DTS/DTB artifacts for SDT builds"
LICENSE = "CLOSED"
SRC_URI = ""

inherit deploy allarch

do_configure[noexec] = "1"

do_compile() {
    bbnote "Importing external DTS from /dt/${HERMES_EXTERNAL_DTS}"
    if [ ! -f "/dt/${HERMES_EXTERNAL_DTS}" ]; then
        bbfatal "Required DTS not found: /dt/${HERMES_EXTERNAL_DTS}"
    fi

    bbnote "Importing external DTB from /dt/${HERMES_EXTERNAL_DTB}"
    if [ ! -f "/dt/${HERMES_EXTERNAL_DTB}" ]; then
        bbfatal "Required DTB not found: /dt/${HERMES_EXTERNAL_DTB}"
    fi

    install -d ${B}
    install -m 0644 "/dt/${HERMES_EXTERNAL_DTS}" "${B}/system-top.dts"
    install -m 0644 "/dt/${HERMES_EXTERNAL_DTB}" "${B}/${HERMES_EXTERNAL_DTB}"

    # Stage the full SDT companion set so Yocto's device-tree build can
    # resolve the generated includes exactly as produced by sdtgen.
    find /dt -maxdepth 1 -type f \( -name "*.dtsi" -o -name "*.yaml" \) -exec install -m 0644 {} ${B}/ \;
    if [ -d /dt/include ]; then
        cp -r /dt/include ${B}/
    fi
}

do_install() {
    install -d ${D}${datadir}/sdt/${MACHINE}
    install -m 0644 "${B}/system-top.dts" "${D}${datadir}/sdt/${MACHINE}/system-top.dts"
    find ${B} -maxdepth 1 -type f \( -name "*.dtsi" -o -name "*.yaml" \) -exec install -m 0644 {} ${D}${datadir}/sdt/${MACHINE}/ \;
    if [ -d ${B}/include ]; then
        cp -r ${B}/include ${D}${datadir}/sdt/${MACHINE}/
    fi
}

do_deploy() {
    install -d ${DEPLOYDIR}
    install -m 0644 "${B}/${HERMES_EXTERNAL_DTB}" "${DEPLOYDIR}/hermes-external.dtb"
    bbnote "Deployed external DTB to ${DEPLOYDIR}/hermes-external.dtb"
}

addtask deploy after do_compile before do_build

SYSROOT_DIRS += "${datadir}/sdt"
FILES:${PN} += " \
    ${datadir}/sdt/${MACHINE}/system-top.dts \
    ${datadir}/sdt/${MACHINE}/*.dtsi \
    ${datadir}/sdt/${MACHINE}/*.yaml \
    ${datadir}/sdt/${MACHINE}/include \
    ${datadir}/sdt/${MACHINE}/include/* \
"