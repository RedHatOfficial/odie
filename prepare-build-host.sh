#!/usr/bin/env bash

#
# Make sure the POOL_ID has the following repositories:
#
#   rhel-7-server-rpms
#   rhel-7-server-extras-rpms
#   rhel-7-server-ose-3.11-rpms
#   rhel-7-server-ansible-2.6-rpms
#   rhel-server-rhscl-7-rpms
#
RHSM_USER=YOUR_RHSM_LOGIN_HERE
RHSM_PASS=YOUR_RHSM_PASSWORD_HERE
POOL_ID=YOUR_POOL_ID_HERE

subscription-manager register --username=$RHSM_USER --password="$RHSM_PASS"
subscription-manager attach --pool=$POOL_ID

yum install -y make
make setup_repos

yum -y update
yum -y install \
    ansible createrepo git psmisc yum-utils docker genisoimage isomd5sum
yum -y install \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum-config-manager --disable epel
yum -y --enablerepo=rhel-7-server-optional-rpms --enablerepo=epel install \
    maven python2-pip
pip install docker-py PyYAML
yum -y clean all && rm -fr /var/cache/yum
systemctl enable docker
systemctl reboot

