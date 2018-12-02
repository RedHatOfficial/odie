#!/usr/bin/env bash
set +e
set +u
set +x

RUN_DIR=$(realpath $( dirname $0 ))
cd $RUN_DIR/..

BUILD_ROOT=${BUILD_ROOT:-output}
OUTPUT_DIR="${BUILD_ROOT}/Packages"
mkdir -p ${OUTPUT_DIR}

LOG_DIR=${ROOT_DIR:-/opt/odie/src/manifests/}
PROCESSED_FILE=${PROCESSED_FILE:-${LOG_DIR}/base-rpms.txt.processed}

cat ${PROCESSED_FILE}  | xargs yumdownloader --destdir ${OUTPUT_DIR}
