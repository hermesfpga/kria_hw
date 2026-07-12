#!/bin/sh
set -eu

STAMP_DIR="/var/lib/hermes"
STAMP_FILE="${STAMP_DIR}/rootfs-expanded"

log() {
    echo "hermes-autoexpand-rootfs: $*"
}

if [ -f "${STAMP_FILE}" ]; then
    log "already expanded; nothing to do"
    exit 0
fi

ROOT_DEV="$(findmnt -n -o SOURCE / || true)"
if [ -z "${ROOT_DEV}" ]; then
    log "could not determine root source"
    exit 0
fi

# Resolve /dev/root style aliases where possible.
ROOT_DEV="$(readlink -f "${ROOT_DEV}" 2>/dev/null || echo "${ROOT_DEV}")"
if [ ! -b "${ROOT_DEV}" ]; then
    ROOT_MAJMIN="$(findmnt -n -o MAJ:MIN / || true)"
    if [ -n "${ROOT_MAJMIN}" ]; then
        ROOT_DEV_FROM_MM="$(lsblk -nr -o MAJ:MIN,PATH | awk -v mm="${ROOT_MAJMIN}" '$1 == mm {print $2; exit}')"
        if [ -n "${ROOT_DEV_FROM_MM}" ] && [ -b "${ROOT_DEV_FROM_MM}" ]; then
            ROOT_DEV="${ROOT_DEV_FROM_MM}"
        fi
    fi
fi

if [ ! -b "${ROOT_DEV}" ]; then
    log "root source is not a block device: ${ROOT_DEV}"
    exit 0
fi

ROOT_FS="$(findmnt -n -o FSTYPE / || true)"
case "${ROOT_FS}" in
    ext2|ext3|ext4) ;;
    *)
        log "unsupported root filesystem '${ROOT_FS}'; skipping"
        exit 0
        ;;
esac

BASENAME="$(basename "${ROOT_DEV}")"
DISK=""
PART=""

case "${BASENAME}" in
    mmcblk*p[0-9]*)
        DISK="/dev/${BASENAME%p*}"
        PART="${BASENAME##*p}"
        ;;
    nvme*n*p[0-9]*)
        DISK="/dev/${BASENAME%p*}"
        PART="${BASENAME##*p}"
        ;;
    sd*[0-9]*)
        DISK="/dev/$(echo "${BASENAME}" | sed -E 's/[0-9]+$//')"
        PART="$(echo "${BASENAME}" | sed -E 's/^.*[^0-9]([0-9]+)$/\1/')"
        ;;
    *)
        log "unsupported root partition naming: ${ROOT_DEV}"
        exit 0
        ;;
esac

if [ -z "${DISK}" ] || [ -z "${PART}" ] || [ ! -b "${DISK}" ]; then
    log "could not derive parent disk from ${ROOT_DEV}"
    exit 0
fi

log "expanding partition ${PART} on ${DISK} for root device ${ROOT_DEV}"
parted -s "${DISK}" "resizepart ${PART} 100%" || {
    log "parted resize failed"
    exit 1
}

partprobe "${DISK}" || true
udevadm settle || true

log "resizing filesystem on ${ROOT_DEV}"
resize2fs "${ROOT_DEV}"

mkdir -p "${STAMP_DIR}"
touch "${STAMP_FILE}"
log "root filesystem expansion complete"
