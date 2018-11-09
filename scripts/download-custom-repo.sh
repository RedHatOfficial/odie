#!/usr/bin/env bash
set +e
set +u
set +x

RUN_DIR=$(realpath $( dirname $0 ))
push $RUN_DIR

OUTPUT_DIR="./output/Packages"
mkdir -p ${OUTPUT_DIR}

COMP_PATH=$(realpath -L ./conf/bootable/comps.xml )
GROUP=${OUTPUT_DIR}/groups.xml

# Compiling meta RPM to work around python-docker issue
rm -rf /tmp/rpmbuild
rpmbuild -bb contrib/python-docker.spec  --define "_rpmdir /tmp/rpmbuild"
mv  /tmp/rpmbuild/x86_64/python-docker-0.0.1-1.x86_64.rpm ${OUTPUT_DIR}

export OCP_VERSION=$(./contrib/bin/yaml_linux_amd64 read /opt/odie/config/ocp.yml ocp_version)

yumdownloader -x \*i686 --archlist x86_64 --destdir ${OUTPUT_DIR} $(cat ./conf/*-rpms.txt| sort -u | envsubst)

cp -f $COMP_PATH ${GROUP}
cd ${OUTPUT_DIR}/..

/usr/bin/createrepo -g Packages/groups.xml .
