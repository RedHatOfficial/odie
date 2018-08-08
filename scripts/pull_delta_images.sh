#!/bin/bash


PATCH_VERSION=$(cat INSTALLER_VERSION  | perl -pe 's/(\d+\.\d+\.\d+)(.*)?/\1/;')

mkdir -p output/delta_images
ansible-playbook playbooks/container_images/pull.yml -e "odie_images_dir=`pwd`/output/delta_images" -e "images_file=`pwd`/conf/patch-images.yml" -e "{"image_types": [${PATCH_VERSION}]}" -vv
