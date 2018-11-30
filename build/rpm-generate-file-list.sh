#!/bin/bash
set -u
#set -x

OUTPUT_DIR=${ROOT_DIR:-/opt/odie/src/output/}
LOG_DIR=${ROOT_DIR:-/opt/odie/src/manifests/}
PACKAGES_DIR=${PACKAGES_DIR:-${OUTPUT_DIR}/Packages}

PACKAGES_FILE=${PACKAGES_FILE:-/opt/odie/src/conf/base-rpms.txt}
PARSED_FILE=${PARSED_FILE:-${LOG_DIR}/parsed_packages.txt}
FOUND_FILE=${FOUND_FILE:-${LOG_DIR}/found_packages.txt}
PROGRESS_FILE=${PROGRESS_FILE:-${LOG_DIR}/inprogress.txt}
ERROR_FILE=${ERROR_FILE:-${LOG_DIR}/errored_packages.txt}
MANIFEST_FILE=${MANIFEST_FILE:-${LOG_DIR}/rpm_manifest.txt}

THREADS=${THREADS:-3}

# prep these files
mkdir -p $LOG_DIR
mkdir -p $OUTPUT_DIR
touch $FOUND_FILE $PROGRESS_FILE $ERROR_FILE $FOUND_FILE $PARSED_FILE


# Before we proceed a quick rant -- yum deplist is hot garbage
# There is no way to specify architecture (so it will randomly pick i686
# packages on occasionally.  Also, it fails silently if the package is not found.

function check_dep() {
  NAME=$1

  DEPLIST=$( sudo yum -C deplist $NAME 2>/dev/null)

  # try the package name as is (probably noarch or explicit version)
  if [[ $(echo "$DEPLIST" | wc -l) = 2 ]] ; then
    return 1
  else
    return 0
  fi
}

export COUNT=1


function sort_files() {

  # do other parsing here
  sort -u $PROGRESS_FILE -o $PROGRESS_FILE
  sort -u $FOUND_FILE -o $FOUND_FILE
  sort -u $ERROR_FILE -o $ERROR_FILE
  cat $ERROR_FILE >> $PARSED_FILE
  sort -u $PARSED_FILE -o $PARSED_FILE

  cp $PROGRESS_FILE $MANIFEST_FILE
}

function count() {
  PACKAGES=$(sort -u $PACKAGES_FILE | comm -2 -3 - $PARSED_FILE)
  COUNT=$(echo $PACKAGES | wc -w )

  echo "$(date) - Packages remaining to parse $COUNT "

  if [[ $COUNT = 0  ]]; then
    return 1
  else
    return 0
  fi

}

function process_file() {
  PACKAGES_FILE=$1
  PACKAGES=$(sort -u $PACKAGES_FILE | comm -2 -3 - $PARSED_FILE | head -${THREADS})

  for package in $(echo ${PACKAGES}) ; do
    parse_package "$package" &
  done

  wait

}


function parse_package() {
  PACKAGE=$1
  echo "Processing $PACKAGE"

  export DEPLIST=""

  # To mitigate this loop below will first attempt the package with .x86_64 appended,
  # If the output is empty (2 lines), then we try .noarch
  # then we give up on that package

  check_dep $PACKAGE.x86_64

  if [[ $? = 1 ]]; then
    check_dep $PACKAGE
  fi

  if [[ $? = 1 ]]; then
      (>&2 echo "WARNING: No infomation found for $PACKAGE")
      echo $PACKAGE >> $ERROR_FILE
      continue
  fi

  # good output
  echo "$PACKAGE" >> $PARSED_FILE
  # pyliblzma-0.5.3-11.el7.x86_64
  echo "$DEPLIST" | egrep 'provider:' | egrep -v 'i686|\.el7' | perl -pe 's/^.*: //; s/(.\w+) (.*)$/-\2\1/; s/(.*?)\-\d+\.el7.*?\.(x86_64|noarch)$//;  ' >> $FOUND_FILE
  echo "$DEPLIST" | egrep 'provider:|package:' | grep -v 'i686' | perl -pe 's/^.*: //; s/(.\w+) (.*)$/-\2\1/;'>> $PROGRESS_FILE

   #yumdownloader -x \*i686 --archlist x86_64 --destdir ${OUTPUT_DIR}

}

handler()
{
  wait
  sort_files
  exit 1
}

trap handler SIGINT

# Append the source package list into our "found" file
cat ${PACKAGES_FILE} >> ${FOUND_FILE}
sort -u -o ${FOUND_FILE} $FOUND_FILE

PACKAGES_FILE=${FOUND_FILE}

while [ $COUNT != 0 ]; do
  sort_files
  count
  time process_file ${PACKAGES_FILE}
  echo
done
