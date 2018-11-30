#!/usr/bin/env bash

#
# BEFORE RUNNING THIS SCRIPT...
# Make sure that rhel-server-7.5-x86_64-dvd.iso is in /root
#

useradd admin
useradd apache

rm -rf dist
./odie.sh properties

#cat >> /opt/odie/config/ocp.yml <<EOF1
#ocp_short_version: 3.9
#ocp_version: 3.9
#EOF1

cat > /opt/odie/config/hosts.csv <<EOF2
hostname,flavor,env
jumphost,jumphost,local
EOF2

cat >> /opt/odie/config/images.yml <<EOF3
rhel_iso: /root/rhel-server-7.5-x86_64-dvd.iso
EOF3

./build.sh --full --baseline

