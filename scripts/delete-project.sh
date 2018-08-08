#!/bin/bash

set +u
PROJECT=project/${1}
oc delete ${PROJECT}
watch -g oc get ${PROJECT} >/dev/null
#find -name '.odie*' -delete
#oc delete pv -l project=${1}
