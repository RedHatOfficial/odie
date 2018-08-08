#!/usr/bin/env bash

SCRIPT_NAME=$(basename "$0")
DIR_NAME=$(dirname "$0")

. ${DIR_NAME}/scripts/lib.sh

#set -x
#set -e
#set -u

export OUTPUT_NAME=${OUTPUT_NAME:-""}
# Command Line Arguments
DEBUG=0
FORCE_IMPORT=0
INCLUDE_BUILDS=0
ONLY_IMAGES=0

declare TARGET_PROJECT
declare TAR
declare TAGS

usage() {
    cat <<EOF

      usage: odie app export PROJECT [APP] [--output-name=FILE]
      usage: odie app import [TAR] [--to=PROJECT]

      usage: odie app create PROJECT
        Create a new basic project under ${PROJECTS_DIR}/PROJECT

      ================

      More Info:
        usage: odie app import help
        usage: odie app export help
EOF
}


usage_export() {
    cat <<EOF

      usage: odie app export PROJECT [APP] [--output-name=FILE]

      ================

      Application Export Options:
        ${bold}--output-name NAME${normal}	-	specify the output name
        ${bold}--builds${normal}	-	include the builds in output

EOF
}


export_images() {
  local CONFIG_PATH=${1}/config.yml
  local OUTPUT_PATH=${2}
  local PROJECT_NAME=${3}
  local OUTPUT_NAME=${4}
  cd ${GIT_CLONE}

  mkdir -p ${OUTPUT_PATH}



  if [ -f "${CONFIG_PATH}" ]; then
       IMAGE_STREAM="$(contrib/bin/yaml_linux_amd64 r ${CONFIG_PATH} image_streams | perl -pe 's/[-:]//g;')"

        set +x
       # check that they have defined an image stream (this allows the export to work w\o a running OCP cluster
       if [[ "$IMAGE_STREAM" -ne "null" ]] ; then
           run_cmd ./playbooks/container_images/export-images.yml -e "config_path=${CONFIG_PATH}" -e "odie_images_dir=${OUTPUT_PATH}" -e "project_name=${PROJECT_NAME}" -e "output_name=${OUTPUT_NAME}" & spin $! "Exporting images from OCP"
       fi
  fi
}

tar_dir() {
  #set -x
  TARGET="$1"

  NAME="$(basename ${TARGET})"
  local OUTPUT_DIR=$(realpath ${EXPORT_DIR})
  local ARCHIVE=${OUTPUT_DIR}/${NAME}.tar

  run_cmd pushd ${TARGET}
  run_cmd tar cvf ${ARCHIVE} . & spin $! "Creating TAR archive"

  popd
  rm -rf "${TARGET}"
}


RSYNC_CMD="`which rsync` -avzL -x "


# IDEA: can you make the export more generic??
export_project() {
  #set +e
  PROJECT_NAME=$1
  OUTPUT_NAME=${OUTPUT_NAME:-odie-export-${PROJECT_NAME}-`date +%Y-%m-%d`}

  # TODO: make sure this is being reset after args set
  OUTPUT_PATH="${EXPORT_DIR}/${OUTPUT_NAME}/"

  PROJECT_PATH="${PROJECTS_DIR}"
  #INCLUDES="--include='/${PROJECT_NAME}'"
  mkdir -p ${OUTPUT_PATH}

  EXCLUDES=" --exclude .odie-project-provision --exclude apps "
  if [[ "${INCLUDE_BUILDS}" != 1 ]]; then
    EXCLUDES="${EXCLUDES} --exclude build"
  fi

  run_cmd ${RSYNC_CMD} ${EXCLUDES} ${PROJECT_PATH}/${PROJECT_NAME} ${OUTPUT_PATH}/projects/ & spin $! "Rsyncing project output"
	mkdir -p ${OUTPUT_PATH}/projects/${PROJECT_NAME}/apps

  export_images "${PROJECT_PATH}/${PROJECT_NAME}" "${OUTPUT_PATH}/images/" "${PROJECT_NAME}" "${OUTPUT_NAME}"
  tar_dir "${OUTPUT_PATH}"
}

export_app() {
  local PROJECT_NAME=$1
  local APP_NAME=$2
  OUTPUT_NAME=${OUTPUT_NAME:-odie-export-${PROJECT_NAME}-${APP_NAME}-`date +%Y-%m-%d`}
  #OUTPUT_NAME=odie-export-${PROJECT_NAME}-${APP_NAME}-`date +%Y-%m-%d`

  local APP_PATH="${PROJECTS_DIR}/${PROJECT_NAME}/apps/${APP_NAME}"
  #INCLUDES=' --exclude="*" --include "apps/${APP_NAME}" '

  local OUTPUT_PATH="${EXPORT_DIR}/${OUTPUT_NAME}"
  local OUT_APP_PATH="${OUTPUT_PATH}/apps"

  mkdir -p ${OUT_APP_PATH}

  EXCLUDES="--exclude .odie-app-provision"
  if [[ "${INCLUDE_BUILDS}" != 1 ]]; then
    EXCLUDES="${EXCLUDES} --exclude build"
  fi

  run_cmd ${RSYNC_CMD} ${EXCLUDES} ${APP_PATH} ${OUT_APP_PATH} & spin $! "Rsyncing Application output"

  export_images "${APP_PATH}/" "${OUT_APP_PATH}/${APP_NAME}/images/" "${PROJECT_NAME}" "${OUTPUT_NAME}"
  tar_dir "${OUTPUT_PATH}"
}

provision() {
  cd ${GIT_CLONE}

  if [[ ! -z "${1}" ]]; then
    export ODIE_SELECTED_PROJECT=${1}
  fi

  if [[ ! -z "${2}" ]]; then
    export ODIE_SELECTED_APPLICATION=${2}
  fi

  if [[ ! -z "${TAGS}" ]]; then
    TAG_CMD="--tags ${TAGS}"
  else
    TAG_CMD=""
  fi

  is_oc_logged_in

  run_ansible_play "Provision Application/Project Components" ./playbooks/app_deployment/provision.yml  -v ${TAG_CMD}
}

unprovision() {
  cd ${GIT_CLONE}

  if [[ ! -z "${1}" ]]; then
    export ODIE_SELECTED_PROJECT=${1}
  fi

  if [[ ! -z "${2}" ]]; then
    export ODIE_SELECTED_APPLICATION=${2}
  fi

  if [[ ! -z "${TAGS}" ]]; then
    TAG_CMD="--tags ${TAGS}"
  else
    TAG_CMD=""
  fi

  is_oc_logged_in

  run_ansible_play "Unprovision Application/Project Components" ./playbooks/app_deployment/unprovision.yml  -v ${TAG_CMD}
}

function header() {
  HEADER="Red Hat ODIE Application Provisioner- ${INSTALLER_VERSION}"
  if [[ ! -v NO_HEADER ]]; then
    echo
    echo ${HEADER}
    echo
    echo "- View log file in another terminal : ${bold}tail -f ${LOG_FILE}${normal}  "
    echo
  fi
}


parse_tar() {
  #local TAR=${1}
  local TYPE=${1}

  echo -n $(tar -tf ${TAR} ./${TYPE}/\* --exclude="*/*/*/*" --strip-components=1 --no-wildcards-match-slash 2>/dev/null | perl -ne 'next if /^\s*$|.tar.gz/; s#^./(projects|apps|images)##; s#/|.yml##g;print;' )
}


unsupported_import_function() {
  echo ${bold}[${red}ERROR${normal}${bold}]${normal} Import functionality does not yet support: $1
  exit 1
}

import() {

  if [[ ! -f "${TAR}" ]]; then
    echo ${bold}[${red}ERROR${normal}${bold}]${normal} Import TAR not found: ${TAR}
    exit 1
  fi


  local PROJECTS=$(parse_tar projects)
  local APPS=$(parse_tar apps)

  local PROJECT_COUNT=$(echo ${PROJECTS} | wc  -w )
  local APPS_COUNT=$(echo ${APPS} | wc -w )

  if [[ "${DEBUG}" = 1 ]]; then
    echo "PROJECTS are ${PROJECTS} (${PROJECT_COUNT})"
    echo "APPS are ${APPS} (${APPS_COUNT})"
  fi

	echo "Completed" >/dev/null & spin $! "Preparing Import settings"

  [[ ! -z "${PROJECTS}" &&  "${PROJECT_COUNT}" != 1 ]] && unsupported_import_function "Multiple project import"
  [[ ! -z "${APPS}" &&  "${APPS_COUNT}" != 1 ]] && unsupported_import_function "Multiple apps import"


  mkdir -p "${PROJECTS_DIR}"

  if [[ "${ONLY_IMAGES}" != 1 && "${PROJECT_COUNT}" = 1 ]]; then
    import_project ${PROJECTS}
  fi

  if [[ "${ONLY_IMAGES}" != 1 && "${APPS_COUNT}" = 1 ]]; then
    import_apps ${APPS}
  fi

}


import_project() {
  local PROJECTS=$1

	local TARGET_PROJECT=${TARGET_PROJECT:-$PROJECTS}

	local OUT_PATH="${PROJECTS_DIR}/${TARGET_PROJECT}"

	[[ -d "${OUT_PATH}" ]] && unsupported_import_function "Directory [${OUT_PATH}] already exists, manually delete directory and OpenShift project to proceed"

	tar -C ${PROJECTS_DIR}  --xform="s|projects/${PROJECTS}|${TARGET_PROJECT}|" -xf ${TAR} ./projects/${PROJECTS} & spin $! "Extracting TAR archive of project"
	mkdir -p ${OUT_PATH}/apps
}

import_apps() {
  local APPS=$1

	#[ ${DEBUG} ] && echo "DEBUG: ${TARGET_PROJECT:=""}"
  [[ ! -v TARGET_PROJECT ]] && unsupported_import_function "Must defined ${bold}--to-project${normal} target project"
	local TARGET_PROJECT=${TARGET_PROJECT}

	local APP_PATH="${PROJECTS_DIR}/${TARGET_PROJECT}/apps/"

	local OUT_PATH="${APP_PATH}/${APPS}"

	[[ -d "${OUT_PATH}" ]] && unsupported_import_function "Directory already exists, please manually delete ${OUT_PATH} directory and OpenShift project"
	[[ ! -d "${APP_PATH}" ]] && unsupported_import_function "Project ${TARGET_PROJECT} doesn't exist"

	tar -C ${APP_PATH}  --xform="s|apps/${APPS}|${APPS}|" -xf ${TAR} ./apps/${APPS} & spin $! "Extracting TAR archive for ${APPS}"
}

import_images() {
  local IMAGES=$1

	local TARGET_PROJECT=${TARGET_PROJECT:-$PROJECTS}

	local OUT_PATH="${IMAGES_DIR}/"
	mkdir -p ${OUT_PATH}

	tar -C ${OUT_PATH}  --xform="s|images/${IMAGES}|${IMAGES}|" -xf ${TAR} ./images/${IMAGES}\* & spin $! "Extracting archive"
  run_cmd ./playbooks/container_images/import-images.yml -e "manifest_path=${OUT_PATH}/${IMAGES}.yml" -e "images_target=${OUT_PATH}" -e "ocp_project=${TARGET_PROJECT}" -e "output_name=${OUTPUT_NAME}" & spin $!  "Importing container images into ${TARGET_PROJECT}"
}


usage_import() {
    cat <<EOF

      usage: odie app import [TAR] [--to=PROJECT]

      ================

      Import Options:
        ${bold}--only-images${normal}	-	skip application import and only import images
        ${bold}--to${normal}	-	include everything

EOF
        #${bold}--reuse${normal}	-	use the existing files
#      Experimental:
#        ${bold}--force${normal}	-	delete existing directories/files and force import
#        ${bold}--all${normal}	-	include everything
}


update_crl() {
  cd ${GIT_CLONE}

  if [[ ! -z "${1}" ]]; then
    export ODIE_SELECTED_PROJECT=${1}
  fi

  if [[ ! -z "${2}" ]]; then
    export ODIE_SELECTED_APPLICATION=${2}
  fi

  is_oc_logged_in
  run_ansible_play "Update CRL" ./playbooks/app_deployment/update_crl.yml  -v --tags shutdown,secrets,startup
}

usage_update_crl() {
    cat <<EOF

      usage: odie app update-crl

      ================

      Import Options:
        ${bold}none${normal}

EOF
}

export params="$(getopt -o a,h,d,t: -l debug,only-images,force,to:,tags:,to-project:,help,output-name:,builds,all,reuse,password --name ${SCRIPT_NAME} -- "$@")"


if [[ $? -ne 0 ]]
then
    usage
    exit 1
fi

eval set -- "$params"

while true
do
    case $1 in
        -h|--help)
           usage
           shift
           exit 0
           ;;
        -d|--debug)
           DEBUG=1
           shift
           ;;
        --output-name)
           if [ -n "$2" ]; then
            OUTPUT_NAME="$2"
           else
             echo "ERROR: Must specify output name with ${bold}--output-name${normal}"
            exit 1
           fi
           shift 2
           ;;
        --force)
           FORCE_IMPORT=1
           shift
           ;;
        --only-images)
           ONLY_IMAGES=1
           shift
           ;;
        --password)
          vault_password
          shift
          ;;
        --builds)
           INCLUDE_BUILDS=1
           shift
           ;;
        --to|--to-project)
           TARGET_PROJECT=$2
           shift 2
           ;;
        -t|--tags)
           TAGS=$2
           shift 2
           ;;
        --)
          shift; break ;;
        *)
          echo "Unknown arg: $1"
          exit 1
          ;;
    esac
done

while true
do
  case $1 in
    export)
      if [[ "$2" = "help" ]]; then
        usage_export
        exit 0
      fi
      PROJECT_NAME=$2
      APP_NAME=$3
      if [[ ! -z "${PROJECT_NAME}" && ! -z "${APP_NAME}" ]]; then
        header
        export_app $PROJECT_NAME $APP_NAME
        complete_message "Application Export"
      elif [[ ! -z "${PROJECT_NAME}"  ]]; then
        header
        export_project $PROJECT_NAME
        complete_message "Project Export"
      else
        echo "ERROR: Invalid execution"
        usage_export
        exit 1
      fi
      exit 0
      ;;
    create)
      TAR=/opt/odie/bundles/current
      TARGET_PROJECT=${2}
      echo "its going ${TARGET_PROJECT}"
      header
      import
      complete_message "Project Created"
      exit 0
      shift;;
    import)
      if [[ "$2" = "help" ]]; then
        usage_import
        exit 0
      fi

      TAR=$(realpath ${2})
      header
      import
      complete_message "Application Import"
      exit 0
      shift;;
    provision)
      if [[ "x${2}" = "xhelp" ]]; then
        echo "Function not documented.  Consult Red Hat."
        exit 1
      fi
      header
      provision $2 $3
      complete_message "Application Provisioning"
      exit 0
      ;;
    unprovision)
      if [[ "x${2}" = "xhelp" ]]; then
        echo "Function not documented.  Consult Red Hat."
        exit 1
      fi
      header
      unprovision $2 $3
      complete_message "Application Unprovisioning"
      exit 0
      ;;
    mount)
      if [[ "x${2}" = "xhelp" ]]; then
        echo "Function not documented.  Consult Red Hat."
        exit 1
      fi
      header
      TAGS="pv"
      provision $2 $3
      complete_message "Mounting PV Dirs"
      exit 0
      ;;
    update-crl)
      if [[ "x${2}" = "xhelp" ]]; then
        usage_update_crl
        exit 0
      fi
      header
      update_crl $2 $3
      complete_message "Application Update-CRL"
      exit 0
      ;;
    *)
      echo "Invalid Subcommand: $2"
      usage
      exit 1
      ;;
    esac
done

usage
