#! /bin/sh
# set -x

HOST=$(hostname -s)

RESULT=/tmp/stig-rhel7-ospp-scan

if [[ ! -z "$1" && "$1" = "True" ]]; then
	REMEDIATE="--remediate"
else
	REMEDIATE=""
fi

#REMOTE="--fetch-remote-resources"
REMOTE=""

oscap xccdf eval ${REMOTE} ${REMEDIATE} --profile ospp-rhel7 --report ${RESULT}.html --results ${RESULT}.xml /usr/share/xml/scap/ssg/content/ssg-rhel7-xccdf.xml
exit 0
