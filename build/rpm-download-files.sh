#!/usr/bin/env bash
set +e
set +u
set +x

RUN_DIR=$(realpath $( dirname $0 ))
cd $RUN_DIR/..

BUILD_ROOT=${BUILD_ROOT:-output}
OUTPUT_DIR="${BUILD_ROOT}/Packages"
mkdir -p ${OUTPUT_DIR}

cat manifests/rpm_manifest.txt | xargs yumdownloader -x \*i686 --archlist x86_64 --destdir ${OUTPUT_DIR}
