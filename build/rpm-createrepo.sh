#!/usr/bin/env bash
set +e
set +u
set +x

RUN_DIR=$(realpath $( dirname $0 ))
cd $RUN_DIR/..

BUILD_ROOT=${BUILD_ROOT:-output}
OUTPUT_DIR="${BUILD_ROOT}/Packages"
mkdir -p ${OUTPUT_DIR}

COMP_PATH=$(realpath -L ./conf/bootable/comps.xml )

# WORKAROUND for packaging eror with python-docker
rm -rf /tmp/rpmbuild
rpmbuild -bb contrib/python-docker.spec  --define "_rpmdir /tmp/rpmbuild"
mv  /tmp/rpmbuild/x86_64/python-docker-0.0.1-1.x86_64.rpm ${OUTPUT_DIR}

GROUP=${OUTPUT_DIR}/groups.xml
cp -f $COMP_PATH ${GROUP}
cd ${OUTPUT_DIR}/..
pwd
/usr/bin/createrepo -g Packages/groups.xml .
