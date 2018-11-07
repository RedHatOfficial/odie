#!/bin/bash
. scripts/lib.sh

BASEDIR=$(dirname "$(readlink -f "$0")")
VERSION=$(cat INSTALLER_VERSION)
SCRIPT_NAME=$(basename "$0")

BUILD_FLAGS_PRE="partial_clean"
BUILD_FLAGS_MAIN="primary"
BUILD_FLAGS_POST=""

export PROVISION_ODIE=0

function git_tag() {
  git rev-list ${VERSION} --
  RESULT=$?

  if [[ "${RESULT}" = 128 ]]; then
    echo "Defining default tag with no release nodes: $VERSION "
    git tag ${VERSION}
  else
    git tagm ${VERSION} HEAD
  fi
}

function bump() {
  VERSION=0.$(./contrib/bin/semver bump build rc-`date +%Y%m%d-%H-%M-%S` `cat INSTALLER_VERSION `)
  #git stash
  echo "${VERSION}" > INSTALLER_VERSION
  #git commit -m "Bumping to ${VERSION}" INSTALLER_VERSION
  #git stash pop
}

function usage() {
  cat <<EOF
${bold} ODIE Build Script ${normal}

${bold}${underline}Media Options${normal}
	--full		-f	Download the latest RPMS and complete
						set of container images (conf/base-images.yml)
	--delta		-d	Download the RPM deltas, generate CVE 
						changelog and the duelta images (conf/delta-images.yml)
	--rpm			-m	Download the latest RPMs


${bold}${underline}Build Output Options${normal}
	--baseline		-b	Create the baseline (complete) ISO
	--patch			-p	Create a patch (delta) ISO [default]
	--release		-r	Generate PDF, create git tag, stage output
						in odie-media repo (TODO)

${bold}${underline}General Options${normal}
	--clean			-c	Clean the output and dist directories
	--none			-n	Remove all the default operations
	--deploy			-t	Provision a ODIE cluster using this ISO via KVM
	--help			-h	Display this useful help information
	--bump			-u	Increment the version number for the build & commit them 
						(${bold}rebase these ${underline}before${normal}${bold} pushing!${normal}) 

EOF
}

export params="$(getopt -o c,i,p,d,f,r,b,h,n,m,u,t -l clean,images,patch,delta,full,release,baseline,help,none,rpm,bump,deploy --name "${SCRIPT_NAME}" -- "$@")"

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
        --baseline|-b)
           export BUILD_FLAGS_MAIN="${BUILD_FLAGS_MAIN} stage_rhel_iso"
           export BUILD_FLAGS_POST="${BUILD_FLAGS_POST} baseline_iso"
           shift
           ;;
        --patch|-p)
           export BUILD_FLAGS_POST="${BUILD_FLAGS_POST} patch_iso"
           shift
           ;;
        --deploy|-t)
           PROVISION_ODIE=1
           shift
           ;;
        --full|-f)
           export BUILD_FLAGS_PRE="${BUILD_FLAGS_PRE} full_media"
           shift
           ;;
        --delta|-d)
           export BUILD_FLAGS_PRE="${BUILD_FLAGS_PRE} delta_media"
           shift
           ;;
        --clean|-c)
           export BUILD_FLAGS_PRE="clean ${BUILD_FLAGS_PRE}"
           shift
           ;;
        --rpm|-m)
           export BUILD_FLAGS_MAIN="${BUILD_FLAGS_MAIN} rpms"
           shift
           ;;
        --bump|-u)
           bump
           shift
           ;;
        --none|-n)
           git_tag
           export BUILD_FLAGS_PRE=""
           export BUILD_FLAGS_MAIN=""
           export BUILD_FLAGS_POST=""
           shift
           ;;
        --release|-r)
           git_tag
           export BUILD_FLAGS_PRE="${BUILD_FLAGS_PRE}"
           export BUILD_FLAGS_MAIN="${BUILD_FLAGS_MAIN}"
#           export BUILD_FLAGS_POST="create_docs ${BUILD_FLAGS_POST}"
           shift
           ;;
        --)
          shift; break ;;
    esac
done

export ISO_NAME=dist/RedHat-ODIE-${VERSION}.iso

function make_odie() { 
  set +x
  run_cmd make ${BUILD_FLAGS_PRE} ${BUILD_FLAGS_MAIN} ${BUILD_FLAGS_POST} BUILD_VERSION=${VERSION} ISO_NAME=${ISO_NAME}
}

function header() {
  export HEADER="Red Hat ODIE Build Script - ${bold}ISO=${ISO_NAME}${normal}"
  echo
  echo ${HEADER}
  echo
  echo "- View log file in another terminal : ${bold}tail -f ${LOG_FILE}${normal}  "
  echo
}

header
make_odie & spin $! "Building ${VERSION}"

if [[ "${PROVISION_ODIE}" = 1 ]]; then
  ${BASEDIR}/deploy.sh $(realpath ${ISO_NAME})
fi
