#!/usr/bin/env bash

# Define paths
TMP_PATH="/tmp"
LOG_FILE="${TMP_PATH}/log.txt"

loaderdisk="$(blkid | grep "6234-C863" | cut -c 1-8 | awk -F\/ '{print $3}')"

export BOOTLOADER_PATH="/mnt/${loaderdisk}1"
export SLPART_PATH="/mnt/${loaderdisk}2"  # Synologic partition
export CACHE_PATH="/mnt/${loaderdisk}3"

ORI_ZIMAGE_FILE="${SLPART_PATH}/zImage"
MOD_ZIMAGE_FILE="${CACHE_PATH}/zImage-dsm"

set -o pipefail # Get exit code from process piped

# Sanity check
[ -f "${ORI_ZIMAGE_FILE}" ] || (die "${ORI_ZIMAGE_FILE} not found!" | tee -a "${LOG_FILE}")

echo -n "Patching zImage"

rm -f "${MOD_ZIMAGE_FILE}"
echo -n "."
# Extract vmlinux
/home/tc/tools/bzImage-to-vmlinux.sh "${ORI_ZIMAGE_FILE}" "${TMP_PATH}/vmlinux" >"${LOG_FILE}" 2>&1 || dieLog
echo -n "."
# Patch boot params and ramdisk check
/home/tc/tools/kpatch "${TMP_PATH}/vmlinux" "${TMP_PATH}/vmlinux-mod" >"${LOG_FILE}" 2>&1 || dieLog
echo -n "."
# rebuild zImage
/home/tc/tools/vmlinux-to-bzImage.sh "${TMP_PATH}/vmlinux-mod" "${MOD_ZIMAGE_FILE}" >"${LOG_FILE}" 2>&1 || dieLog
echo -n "."
# Update HASH of new DSM zImage
HASH="`sha256sum ${ORI_ZIMAGE_FILE} | awk '{print$1}'`"
#writeConfigKey "zimage-hash" "${HASH}" "${USER_CONFIG_FILE}"
echo
