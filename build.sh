#!/bin/bash
. scripts/lib.sh

BASEDIR=$(dirname "$(readlink -f "$0")")
VERSION=$(cat INSTALLER_VERSION)
SCRIPT_NAME=$(basename "$0")

BUILD_FLAGS_PRE="partial_clean"
BUILD_FLAGS_MAIN=""
BUILD_FLAGS_POST=""
SHOW_TAIL=0
INTERACTIVE=1
RELEASE=0
BUILD_BASE=0
BUILD_EXTRA=0
BUILD_APPDEV=0
BUILD_MEGA=0

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
  VERSION=$(./contrib/bin/semver bump build build-`date +%Y%m%d-%H-%M-%S` `cat INSTALLER_VERSION `)
  echo "${VERSION}" > INSTALLER_VERSION
}

function usage() {
  cat <<EOF
${bold} ODIE Build Script ${normal}

${bold}${underline}Media Options${normal}
	--full		-f	Download the latest RPMS and complete
						set of container images (conf/base-images.yml)
	--rpm			-m	Download the latest RPMs


${bold}${underline}Build Output Options${normal}
	--baseline		-b	Create the baseline (complete) ISO
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

export params="$(getopt -o c,i,f,r,b,h,n,m,u,d -l all,clean,images,full,release,base,extra,appdev,mega,help,none,rpm,bump,deploy,tail --name "${SCRIPT_NAME}" -- "$@")"

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
        --tail)
          echo "Realtime tailing of log"
          INTERACTIVE=0
          SHOW_TAIL=1
          shift
          ;;
        --base)
           BUILD_BASE=1
           shift
           ;;
        --extra)
           BUILD_EXTRA=1
           shift
           ;;
        --appdev)
           BUILD_APPDEV=1
           shift
           ;;
        --mega)
           BUILD_MEGA=1
           shift
           ;;
        --all)
           BUILD_BASE=1
           BUILD_APPDEV=1
           BUILD_EXTRA=1
           BUILD_MEGA=1
           shift
           ;;
        --deploy|-d)
           PROVISION_ODIE=1
           shift
           ;;
        --full|-f)
           export BUILD_FLAGS_MAIN="${BUILD_FLAGS_MAIN} full_media"
           shift
           ;;
        --images|-i)
           export BUILD_FLAGS_MAIN="${BUILD_FLAGS_MAIN} pull_images"
           shift
           ;;
        --rpms|--rpm|-m)
           export BUILD_FLAGS_MAIN="${BUILD_FLAGS_MAIN} rpms"
           shift
           ;;
        --clean|-c)
           export BUILD_FLAGS_PRE="clean ${BUILD_FLAGS_PRE}"
           shift
           ;;
        --bump|-b)
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
           RELEASE=1
           #export BUILD_FLAGS_PRE="${BUILD_FLAGS_PRE}"
           #export BUILD_FLAGS_MAIN="${BUILD_FLAGS_MAIN}"
           export BUILD_FLAGS_POST="create_docs ${BUILD_FLAGS_POST}"
           shift
           ;;
        --)
          shift; break ;;
        *)
          shift; break ;;
    esac
done

ISO_NAME=dist/RedHat-ODIE-${VERSION}-generic.iso

function make_odie() {
  set +x
  ISO_TYPE=$1
  run_cmd make ${BUILD_FLAGS_PRE} ${BUILD_FLAGS_MAIN} ${BUILD_FLAGS_POST} BUILD_VERSION=${VERSION} ISO_NAME=${ISO_NAME} OUTPUT_DISC=${ISO_TYPE} OUTPUT_DIR=output/
}


function build_iso_type() {
  ISO_TYPE=$1
  export ISO_NAME=dist/RedHat-ODIE-${VERSION}-${ISO_TYPE}.iso
  export BUILD_FLAGS_MAIN="${ISO_TYPE}_iso"
  export BUILD_FLAGS_PRE="${BUILD_FLAGS_PRE} clean"
  make_odie $ISO_TYPE & spin $! "Building ${ISO_TYPE} ISO"
}

function header() {
  export HEADER="Red Hat ODIE Build Script"
  echo ${HEADER}
  echo "- View log file in another terminal : ${bold}tail -f ${LOG_FILE}${normal}  "
}
header

DEPLOY_ISO=""

# if BUILD_FLAGS_MAIN has args it is a media build
if [[ ! -z $BUILD_FLAGS_MAIN ]]; then
  make_odie $BUILD_FLAGS_MAIN & spin $! "Downloading Media"
fi

if [[ $BUILD_BASE = 1 ]]; then
  build_iso_type base
  export DEPLOY_ISO=${ISO_NAME}
fi

if [[ $BUILD_EXTRA = 1 ]]; then
  build_iso_type extra
fi

if [[ $BUILD_APPDEV = 1 ]]; then
  build_iso_type appdev & spin $! "Building AppDev ISO"
fi

if [[ $BUILD_MEGA = 1 ]]; then
  build_iso_type mega
  # use the mega ISO if possible
  export DEPLOY_ISO=${ISO_NAME}
fi

if [[ "${PROVISION_ODIE}" = 1 ]]; then
  sudo ${BASEDIR}/deploy.sh --iso $(realpath ${DEPLOY_ISO})
fi
