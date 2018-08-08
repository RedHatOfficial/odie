#!/bin/bash
# A standalone deployment script for provisioning of VMs via the `odie-provision.yml` playbook.
#
# include::../target/help-deploy.sh.adoc[]
#
# See:
# - <<build.sh,build.sh>>
#

. scripts/lib.sh

export VERSION=$(cat INSTALLER_VERSION)
SCRIPT_NAME=$(basename "$0")
export ISO_NAME=dist/RedHat-ODIE-${VERSION}.iso

function usage() {
  cat <<EOF
${bold} ODIE Deploy Script ${normal}

${bold}${underline}General Options${normal}
	--help			-h	Display this useful help information

EOF
}

export params="$(getopt -o h -l help --name "${SCRIPT_NAME}" -- "$@")"

if [[ $? -ne 0 ]]; then
  usage
  exit 1
fi

eval set -- "$params"

while true
do
    case $1 in
        --help|-h)
           usage
           exit 0
           ;;
        --)
          shift; break ;;
    esac
done


function header() {
  export HEADER="Red Hat ODIE Deploy Script - ${bold}ISO=${ISO_NAME}${normal}"
  echo
  echo ${HEADER}
  echo
  echo "- View log file in another terminal : ${bold}tail -f ${LOG_FILE}${normal}  "
  echo
}


if [[ ! -z "$1" ]]; then
  ISO_NAME=$1
fi

header
./odie-provision.yml -e "boot_iso=$(realpath ${ISO_NAME})"
