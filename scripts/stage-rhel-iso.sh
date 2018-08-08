#!/bin/bash
# This script will stage files from the RHEL ISO to make the odie disc
# bootable

# This script accepts two parameters:
# $1 = the location to the RHEL 7.x ISO
# $2 = the output location to copy the files

ISO=$(./contrib/bin/yaml_linux_amd64 read /opt/odie/config/images.yml rhel_iso)
OUTPUT_DIR=$1

shift
shift
if [[ ! -f "${ISO}" ]]; then
  echo "${red}[ERROR]${normal} ISO ${ISO} not found. " >> /dev/stderr
  exit 1
fi
CONTENT_DIR=$(mktemp -d)

echo "Mounting ISO.. "
sudo mount -o ro ${ISO} ${CONTENT_DIR}

function unmount_iso {
        if [[ -d ${CONTENT_DIR} ]]; then
            cd
            echo "Unmounting ISO"
            sudo umount ${CONTENT_DIR}
            rmdir ${CONTENT_DIR}
        fi
}

trap unmount_iso EXIT INT TERM


INSTALLER=$(cat INSTALLER_VERSION)

set -x
set -e
echo "Create output directories"
mkdir -p ${OUTPUT_DIR}/{isolinux,ks,ks_output}
echo "Copy files to output directory"
cp conf/bootable/discinfo ${OUTPUT_DIR}/.discinfo
cp conf/bootable/{media.repo,GPL,EULA} ${OUTPUT_DIR}/
cp -nr ${CONTENT_DIR}/{LiveOS,images,repodata} ${OUTPUT_DIR}/
#find ${CONTENT_DIR} -maxdepth 1 -type f -exec cp {} ${CONTENT_DIR}/ \;
cp -n ${CONTENT_DIR}/isolinux/* ${OUTPUT_DIR}/isolinux/
cp -f conf/bootable/isolinux.cfg conf/bootable/f*txt ${OUTPUT_DIR}/isolinux/
/usr/bin/sed -i -e "s/INSTALLER_VERSION/${INSTALLER}/" ${OUTPUT_DIR}/isolinux/isolinux.cfg

echo "Generate Jumphost Kickstarts"
KS=$(realpath ${OUTPUT_DIR}/ks)
KS_OUT=$(realpath ${OUTPUT_DIR}/ks_output)

./playbooks/media_preparation/generate_jumphost_ks.yml -e "kickstart_dir=${KS_OUT}/" -e 'installer_method=gui'
mv ${KS_OUT}/*.cfg ${KS}/jumphost-gui-ks.cfg
./playbooks/media_preparation/generate_jumphost_ks.yml -e "kickstart_dir=${KS_OUT}/" -e 'installer_method=text'
mv ${KS_OUT}/*.cfg ${KS}/jumphost-text-ks.cfg
rmdir  ${KS_OUT}

#find ${OUTPUT_DIR} -exec chmod u+w {} \;
