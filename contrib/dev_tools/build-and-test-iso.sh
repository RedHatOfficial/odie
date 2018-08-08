#!/bin/bash

# Build and Test ISO
#   this script is used to compile new ISOs and test them against an existing VM
#
# This assumes that you have a host computer called "gateway" that has a vm called "bootableTest"
#     With an ISO available at /blah/see/the/code/disc.iso

# Future versions will use ansible to orchestrate the entire provisioning!!

make download_rpms dvd

ssh gateway -C "virsh destroy bootableTest"
sleep 2
scp dist/RedHat-ODIE-snapshot.iso root@gateway:/mnt/ISOs/custom-rhel-01.iso; sleep 2
ssh gateway -C "virsh start bootableTest"
