#!/usr/bin/env bash
# Jolokia JVM Metrics
#
#   This script will monitor the JVM inside of a pod and observe
#   Its memory characteristics.  This watches the heap spaces, garbage
#   collection occurances & CPU time, number of threads and number of open
#   file handles.
#
#   This script was based off the JDK tool jstat and will report on these 
#   metrics every 5 seconds.  It functions by performing a curl request to the
#   jolokia agent inside of the JBoss image.

set -e
TOKEN=`oc whoami -t`
STATUS=`oc status`
PROJECT=`echo $STATUS | head -1 | awk '{print $3}'`
SERVER=`echo $STATUS | head -1 | awk '{print $6}'`
POD=$1
JQ="/opt/odie/src/contrib/bin/jq-linux64"

# check if pod exists 
oc get pod $POD >/dev/null

LINE_FORMAT="%-22s %-20s %-18s %-15s %-10s %-12s\n"

function format_numbers() {
  TITLE=$1
  USED=$2
  MAX=$3
  echo -n "$((${USED} / 1024 / 1024))/$((${MAX} / 1024 / 1024 )) MB ($( echo "scale=2;${USED}/${MAX}" | bc ))"
}

print_stats() {
  JMX=$1

  SURVIVOR_MBEAN="java.lang:type=MemoryPool,name=PS Survivor Space"
  EDEN_MBEAN="java.lang:type=MemoryPool,name=PS Eden Space"
  OLDGEN_MBEAN="java.lang:type=MemoryPool,name=PS Old Gen"

  SURVIVOR_MAX=`echo $JMX | ${JQ} '.value["'"${SURVIVOR_MBEAN}"'"]["Usage"]["max"]'`
  SURVIVOR_USED=`echo $JMX | ${JQ} '.value["'"${SURVIVOR_MBEAN}"'"]["Usage"]["used"]'`
  EDEN_MAX=`echo $JMX | ${JQ} '.value["'"${EDEN_MBEAN}"'"]["Usage"]["max"]'`
  EDEN_USED=`echo $JMX | ${JQ} '.value["'"${EDEN_MBEAN}"'"]["Usage"]["used"]'`
  OLDGEN_MAX=`echo $JMX | ${JQ} '.value["'"${OLDGEN_MBEAN}"'"]["Usage"]["max"]'`
  OLDGEN_USED=`echo $JMX | ${JQ} '.value["'"${OLDGEN_MBEAN}"'"]["Usage"]["used"]'`

  THREAD_COUNT=`echo $JMX | ${JQ} '.value["java.lang:type=Threading"]["ThreadCount"]'`
  OPEN_FILE_COUNT=`echo $JMX | ${JQ} '.value["java.lang:type=OperatingSystem"]["OpenFileDescriptorCount"]'`

  FULL_GC_COUNT=`echo $JMX | ${JQ} '.value["java.lang:type=GarbageCollector,name=PS MarkSweep"]["CollectionCount"]' `
  FULL_GC_TIME=`echo $JMX | ${JQ} '.value["java.lang:type=GarbageCollector,name=PS MarkSweep"]["CollectionTime"]' `
  YOUNG_GC_COUNT=`echo $JMX | ${JQ} '.value["java.lang:type=GarbageCollector,name=PS Scavenge"]["CollectionCount"]' `
  YOUNG_GC_TIME=`echo $JMX | ${JQ} '.value["java.lang:type=GarbageCollector,name=PS Scavenge"]["CollectionTime"]' `


  printf "${LINE_FORMAT}" "$( format_numbers "EdenSpace" $(($EDEN_USED + $SURVIVOR_USED)) $(($EDEN_MAX + $SURVIVOR_MAX)) )" "$( format_numbers "OldGen" ${OLDGEN_USED} ${OLDGEN_MAX} )"  "${YOUNG_GC_COUNT}x (${YOUNG_GC_TIME}ms)" \ "${FULL_GC_COUNT}x (${FULL_GC_TIME}ms)" "${THREAD_COUNT}" "${OPEN_FILE_COUNT}"

}


printf "${LINE_FORMAT}" "NewGen (Survivor+Eden)" "OldGen" "Young GC" "Full GC" "Threads" "Open Files"

while true; do
  JMX=`curl -s "${SERVER}/api/v1/namespaces/${PROJECT}/pods/https:$POD:8778/proxy/jolokia/?maxDepth=7&maxCollectionSize=500&ignoreErrors=true&canonicalNaming=false" -H "origin: \
  ${SERVER}" -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.8' -H "authorization: Bearer ${TOKEN}" -H 'pragma: no-cache'  -H 'content-type: text/json' -H 'accept: application/json, text/javascript, */*; q=0.01' \
  --data-binary '{"type":"read","mbean":"java.lang*:*"}' --compressed --insecure`
  print_stats "$JMX"
  sleep 5
done
