#!/bin/bash

# get release version
RELEASE=$(cat /etc/redhat-release)
YUM_ARGS=""

# ensure latest versions
yum update -y --setopt=tsflags=nodocs

# if the release is a red hat version then we need to set additional arguments for yum repositories
RED_HAT_MATCH='^Red Hat.*$'
if [[ $RELEASE =~ $RED_HAT_MATCH ]]; then
  YUM_ARGS='--disablerepo=\* --enablerepo=rhel-7-server-rpms --enablerepo=rhel-server-rhscl-7-rpms --enablerepo=rhel-7-server-optional-rpms'
fi

# enable epel when on CentOS
CENTOS_MATCH='^CentOS.*'
if [[ $RELEASE =~ $CENTOS_MATCH ]]; then
  yum install -y epel-release
fi

# install required packages
yum install -y --setopt=tsflags=nodocs $YUM_ARGS httpd mod_ssl mod_session apr-util-openssl gettext nss_wrapper

# clean up yum to make sure image isn't larger because of installations/updates
yum clean all
rm -rf /var/cache/yum/*
rm -rf /var/lib/yum/*
