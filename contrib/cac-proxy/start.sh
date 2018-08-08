#!/bin/bash

# set up user id into passwd wrapper
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
cat /apache/passwd.template | envsubst > /tmp/passwd
export LD_PRELOAD=/usr/lib64/libnss_wrapper.so
export NSS_WRAPPER_PASSWD=/tmp/passwd
export NSS_WRAPPER_GROUP=/etc/group
USER_NAME=$(id -un)

# show that alternate user IDs are being honored
echo "Running with user ${USER_NAME} (${USER_ID}) and group ${GROUP_ID}"

# collect information about namespace (and do something if running without kubernetes/openshift)
CURRENT_NAMESPACE="docker"
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/namespace ]; then
  CURRENT_NAMESPACE=`cat /var/run/secrets/kubernetes.io/serviceaccount/namespace`
fi
export CURRENT_NAMESPACE

# if the customizable configuration exists use it
CONF_SOURCE="/apache/default-pivproxy.conf"
CONF_TARGET="/etc/httpd/conf.d/01-pivproxy.conf"
if [ -f /config/pivproxy.conf ]; then
  CONF_SOURCE="/config/pivproxy.conf"
fi
echo "Using configuration file from: ${CONF_SOURCE}"
cp ${CONF_SOURCE} ${CONF_TARGET}

# start apache in the foreground
/usr/sbin/httpd -DFOREGROUND
