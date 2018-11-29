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

export params="$(getopt -o hi: -l help,skip-tags:,tags:,iso: --name "${SCRIPT_NAME}" -- "$@")"

if [[ $? -ne 0 ]]; then
  usage
  exit 1
fi

OPTIONS=""

eval set -- "$params"

while true
do
    case $1 in
        --help|-h)
           usage
           exit 0
           ;;
        --iso|-i)
          ISO_NAME="$2"
          shift
          shift
          ;;
        --tags)
          OPTIONS="${OPTIONS} --tags ${2}"
          shift;shift;
          ;;
        --skip-tags)
          OPTIONS="${OPTIONS} --skip-tags ${2}"
          shift;shift;
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


header
./odie-provision.yml -e "boot_iso=$(realpath ${ISO_NAME})" -e @/opt/odie/config/build.yml ${OPTIONS}
