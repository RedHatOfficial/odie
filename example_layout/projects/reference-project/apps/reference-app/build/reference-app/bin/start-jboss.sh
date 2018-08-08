#!/bin/bash

# Updated to run EAP with Java Security Manager enabled
# EAP 6.3 DISA STIG rules
#    V-62243
#    V-62271

echo "Running $JBOSS_IMAGE_NAME image, version $JBOSS_IMAGE_VERSION"

JAVA_OPTS_APPEND="$JAVA_OPTS_APPEND -Djava.security.policy==$JBOSS_HOME/bin/server.policy"

export JAVA_OPTS_APPEND

echo $JBOSS_HOME/bin/standalone.sh \
  -b 0.0.0.0 -bmanagement 127.0.0.1 \
  --server-config=standalone-openshift.xml \
  -Djava.security.policy==$JBOSS_HOME/bin/server.policy \
  -Djava.security.debug=failure \
  -secmgr

exec $JBOSS_HOME/bin/standalone.sh -c standalone-openshift.xml -bmanagement 127.0.0.1 ${JAVA_PROXY_OPTIONS} ${JBOSS_HA_ARGS} ${JBOSS_MESSAGING_ARGS} -secmgr
