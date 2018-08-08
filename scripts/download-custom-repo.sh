#!/usr/bin/env bash
set +e
set +u
set +x

RUN_DIR=$(realpath $( dirname $0 ))

OUTPUT_DIR="${RUN_DIR}/../output/Packages"
COMP_PATH=$(realpath -L ${RUN_DIR}/../conf/bootable/comps.xml )
GROUP=${OUTPUT_DIR}/groups.xml

export OCP_VERSION=$(./contrib/bin/yaml_linux_amd64 read /opt/odie/config/ocp.yml ocp_version)

# yumdownloader -x documented here: https://bugzilla.redhat.com/show_bug.cgi?id=1045871
mkdir -p ${OUTPUT_DIR}
yumdownloader -x \*i686 --archlist x86_64 --destdir ${OUTPUT_DIR} $(cat ${RUN_DIR}/../conf/*-rpms.txt| sort -u | envsubst)

cp -f $COMP_PATH ${GROUP}
cd ${OUTPUT_DIR}/..

/usr/bin/createrepo -g Packages/groups.xml .
