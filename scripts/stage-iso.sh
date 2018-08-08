#!/bin/bash
# This script is a wrapper used to directly invoke the odie stage program from the ISO
# TODO: add argument support

ISO=$1
shift
if [[ ! -f "${ISO}" ]]; then
  echo "${red}[ERROR]${normal} ISO ${ISO} not found. " | tee -a ${LOG_FILE} >> /dev/stderr
  exit 1
fi
CONTENT_DIR=$(mktemp -d)

echo "Mounting ISO.. "
mount -o ro ${ISO} ${CONTENT_DIR}

function unmount_iso {
        if [[ -d ${CONTENT_DIR} ]]; then
            cd
            echo "Unmounting ISO"
            umount ${CONTENT_DIR}
            rmdir ${CONTENT_DIR}
        fi
}

trap unmount_iso EXIT INT TERM
${CONTENT_DIR}/odie.sh stage $*
