#!/usr/bin/env bash
set -u

# Validate required inputs provided by the Makefile/docker run wrapper.
if [ -z "${YOCTO_IMAGE:-}" ] || [ -z "${YOCTO_MACHINE:-}" ] || [ -z "${YOCTO_BUILD_PATH:-}" ] || [ -z "${ARTIFACTS_CONTAINER_DIR:-}" ] || [ -z "${LAYER_CONTAINER_PATH:-}" ]; then
    echo "Missing required environment variables for build_sd_boot.sh" >&2
    exit 2
fi

YOCTO_DTB_NAME="${YOCTO_DTB_NAME:-system-top.dtb}"
YOCTO_DTS_NAME="${YOCTO_DTS_NAME:-system-top.dts}"

# Confirm the mounted DT artifacts are visible inside the container.
echo "Mounted device tree files:"
ls /dt

# Ensure the custom layer and required image config are present.
bitbake-layers add-layer "${LAYER_CONTAINER_PATH}" 2>/dev/null || true
grep -q '^IMAGE_INSTALL:append.*kria-artifacts' conf/local.conf || echo 'IMAGE_INSTALL:append = " kria-artifacts"' >> conf/local.conf

if grep -Eq '^MACHINE[[:space:]]*=' conf/local.conf; then
    sed -i -E "s|^MACHINE[[:space:]]*=.*$|MACHINE = \"${YOCTO_MACHINE}\"|" conf/local.conf
else
    echo "MACHINE = \"${YOCTO_MACHINE}\"" >> conf/local.conf
fi

if grep -Eq '^HERMES_EXTERNAL_DTB[[:space:]]*=' conf/local.conf; then
    sed -i -E "s|^HERMES_EXTERNAL_DTB[[:space:]]*=.*$|HERMES_EXTERNAL_DTB = \"${YOCTO_DTB_NAME}\"|" conf/local.conf
else
    echo "HERMES_EXTERNAL_DTB = \"${YOCTO_DTB_NAME}\"" >> conf/local.conf
fi

if grep -Eq '^HERMES_EXTERNAL_DTS[[:space:]]*=' conf/local.conf; then
    sed -i -E "s|^HERMES_EXTERNAL_DTS[[:space:]]*=.*$|HERMES_EXTERNAL_DTS = \"${YOCTO_DTS_NAME}\"|" conf/local.conf
else
    echo "HERMES_EXTERNAL_DTS = \"${YOCTO_DTS_NAME}\"" >> conf/local.conf
fi

if grep -Eq '^SYSTEM_DTFILE[[:space:]]*=' conf/local.conf; then
    sed -i -E "s|^SYSTEM_DTFILE[[:space:]]*=.*$|SYSTEM_DTFILE = \"/dt/${YOCTO_DTS_NAME}\"|" conf/local.conf
else
    echo "SYSTEM_DTFILE = \"/dt/${YOCTO_DTS_NAME}\"" >> conf/local.conf
fi

# Validate and stage external DTS/DTB artifacts before image build.
YOCTO_LOG="${ARTIFACTS_CONTAINER_DIR}/${YOCTO_BUILD_PATH}/yocto.log"
set -o pipefail
bitbake hermes-external-dtb 2>&1 | tee -a "${YOCTO_LOG}"
EXT_DT_EXIT=${PIPESTATUS[0]}
if [ ${EXT_DT_EXIT} -ne 0 ]; then
    exit ${EXT_DT_EXIT}
fi

# Build image and keep the real bitbake exit code even with tee enabled.
bitbake "${YOCTO_IMAGE}" 2>&1 | tee -a "${YOCTO_LOG}"
BB_EXIT=${PIPESTATUS[0]}

# Resolve Yocto deploy output and export boot artifacts to persistent host storage.
DEPLOY_DIR=$(bitbake -e "${YOCTO_IMAGE}" | sed -n 's/^DEPLOY_DIR_IMAGE="\(.*\)"/\1/p' | head -1)
OUT_BOOT_DIR="${ARTIFACTS_CONTAINER_DIR}/${YOCTO_BUILD_PATH}/boot"
mkdir -p "${OUT_BOOT_DIR}"

if [ -d "${DEPLOY_DIR}" ]; then
    echo "Exporting Yocto .wic.xz image from ${DEPLOY_DIR} to ${OUT_BOOT_DIR}"
    # DEPLOY_DIR_IMAGE typically resolves to:
    # /workspace/build/tmp/deploy/images/<machine>
    # Copy only the newest real timestamped .wic.xz file (not symlinks).
    WIC_FILE=$(find "${DEPLOY_DIR}" -maxdepth 1 -type f -name "*.wic.xz" -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)

    if [ -z "$WIC_FILE" ]; then
        echo "WARNING: No .wic.xz file found in ${DEPLOY_DIR}" >&2
        echo "Top-level deploy contents:" >&2
        ls -lah "${DEPLOY_DIR}" >&2 || true
    else
        cp -av "$WIC_FILE" "${OUT_BOOT_DIR}/"
    fi

    ls -lah "${OUT_BOOT_DIR}"
else
    echo "WARNING: DEPLOY_DIR_IMAGE not found: ${DEPLOY_DIR}"
fi

# Return the original build status for CI/reporting.
exit ${BB_EXIT}
