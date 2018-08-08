#!/bin/bash
###############################################################################
# OpenShift v3 scripts
#
# Author:    nrevo
# Date:      2017-06-08
# Usage:
# Example:
# Comments:
#
#
#############################################################################
# use dirname ${BASH_SOURCE[0]} to get the path to this script
SOURCED_SCRIPT_DIR=$(dirname "$(readlink -f ${BASH_SOURCE[0]})")
BASE_TEMPLATE_DIR=$(dirname "$(readlink -f ${SOURCED_SCRIPT_DIR})")/ocp_templates
GLOBAL_CONFIG_FILE_NAME=app_config.cfg
source ${SOURCED_SCRIPT_DIR}/lib.sh

VARIABLE_OVERRIDE_FILE=build.properties

#############################################################################
# Custom messages that get shown when this script is loaded
# Additional messages called at the bottom of this script
#############################################################################
printf "\n%-80s\n\n" "## Verify environment is ready ###########"
#############################################################################
# End custom messages
#############################################################################

get_app_config_file() {
  local SOURCE_THESE="source ${BASEDIR}/${GLOBAL_CONFIG_FILE_NAME}"

  if [[ -f ${PROJECT_PATH}${GLOBAL_CONFIG_FILE_NAME} ]]; then
    # can't print error message because it will get captured by the "source $(varname)" code
    SOURCE_THESE="${SOURCE_THESE}; source ${PROJECT_PATH}${GLOBAL_CONFIG_FILE_NAME}"
  fi
  if [ -n ${APP_PATH} ]; then
    if [[ -f ${APP_PATH}${GLOBAL_CONFIG_FILE_NAME} ]]; then
      SOURCE_THESE="${SOURCE_THESE}; source ${APP_PATH}${GLOBAL_CONFIG_FILE_NAME}"
    fi
  fi
  echo ${SOURCE_THESE}
}

# Detect if OpenShift Container Platform (OCP) tools (oc) exist
is_oc_command_available() {
  run_cmd which oc & spin $! "Checking if oc command is available"
  if [ $? -ne 0 ]; then
    printf "${red}[Error]${normal} the oc command is not available in the PATH"
    exit 1
  fi
  export CMD_BINARY="`which oc`"
}

create_new_project() {
  run_cmd ${CMD_BINARY} new-project ${PROJECT_NAME} & spin $! "Creating project ${PROJECT_NAME}"
  if [ $? -ne 0 ]; then
    printf "${red}[Error]${normal} unable to create project ${light_green}${PROJECT_NAME}${normal}.\n"
    exit 1
  fi
}
set_project() {
  oc_set_project & spin $! "Switching to project ${PROJECT_NAME}"
  if [ $? -ne 0 ]; then
    printf "${red}[Error]${normal} unable to switch to project ${light_green}${PROJECT_NAME}${normal}.\n"
    printf "${red}[Error]${normal} make sure the project is available and you have permissions to access it.\n"
    exit 1
  fi
}

oc_set_project() {
  if [[ ! -z ${PROJECT_NAME} ]]; then
    run_cmd ${CMD_BINARY} project ${PROJECT_NAME}
    if [ $? -ne 0 ]; then
      exit 1
    fi
  fi
}

oc_new_build() {
  if [[ ! -z ${APPLICATION_NAME} ]]; then
    #  oc new-build --binary=true --strategy=docker --name=${PROJECT_NAME} -i=${IMAGE_NAME}
    run_cmd ${CMD_BINARY} new-build --binary=true --strategy=docker --name=${APPLICATION_NAME} -i=${IMAGE_NAME}
    if [ $? -ne 0 ]; then
      echo -n "Unable to create build.  Respond to error message and try again."
      exit 1
    fi
  fi
}

oc_new_app() {
  if [[ ! -z ${APPLICATION_NAME} ]]; then
    run_cmd ${CMD_BINARY} new-app ${APPLICATION_NAME}
    if [ $? -ne 0 ]; then
      echo -n "Unable to create new application.  Respond to error message and try again."
      exit 1
    fi
  fi
}

expose_service() {
  oc_expose_service & spin $! "Expose http service on 8080"
}

oc_expose_service() {
  if [[ ! -z ${APPLICATION_NAME} ]]; then
    run_cmd ${CMD_BINARY} expose svc/${APPLICATION_NAME}-services-http --port=8080
    if [ $? -ne 0 ]; then
      echo -n "Unable to expose service.  Respond to error message and try again."
      exit 1
    fi
  fi
}

oc_get_route() {
  run_cmd ${CMD_BINARY} get route
}

check_build_artifacts() {
  files_to_check=("Dockerfile" "start-jboss.sh")
  dirs_to_check=("configuration" "deployments" "modules" "properties")

  run_cmd check_build & spin $! "Check for needed build artifacts"
  if [ $? -ne 0 ]; then
    printf "\rUnable to find necessary artifacts\n"
    exit 1
    #run_cmd copy_build_artifacts_from_reference & spin $! "Copy necessary artifacts from fielding kit reference"
  fi
}

check_build() {
  ERROR=0
  for i in "${files_to_check[@]}"
  do
    if [[ ! -f ${APPLICATION_NAME}/$i ]]; then
      printf "\r$i not found in ${APPLICATION_NAME} folder\n"
      ERROR=$((ERROR+1))
    fi
  done
  for i in "${dirs_to_check[@]}"
  do
    if [[ ! -d ${APPLICATION_NAME}/$i ]]; then
      printf "\rFolder $i not found under ${APPLICATION_NAME} and needs to exist\n"
      ERROR=$((ERROR+1))
    fi
  done

  return "$ERROR"
}

# not used
#copy_build_artifacts_from_reference() {
#  ERROR=0
#  for i in "${files_to_check[@]}"
#  do
#    if [[ ! -f ${APPLICATION_NAME}/$i ]]; then
#      printf "\rCopying $i into folder ${APPLICATION_NAME}\n"
#      run_cmd cp -n ${BASEDIR}/fielding_kit_reference/helloworld-mdb/$i ${APPLICATION_NAME}
#      ERROR=$((ERROR+1))
#    fi
#  done
#
#  return "$ERROR"
#}

start_build() {
  oc_start_build ${APPLICATION_NAME} ${BUILD_PATH} & spin $! "Start binary build"
  oc_get_route & spin $! "Displaying available routes"
}

oc_start_build() {
  BC_NAME=$1
  PATH=$2
  if [[ ! -z ${BUILD_PATH} ]]; then
    run_cmd ${CMD_BINARY} start-build ${BC_NAME} ${START_BUILD_ARG} ${PATH} --wait --follow
  else
    echo "Argument specifying binary location is required."
    usage
    exit 1
  fi
}

create_db_from_template() {
  if [ "${DB_PARAM[IMAGE_NAME]}" != "null" ]; then
    run_cmd ${CMD_BINARY} get dc/${APPLICATION_NAME}-postgresql
    if [ $? -ne 0 ]; then
      PG_TEMPLATE_NAME="odie-db"

      if [[ -n "${POSTGRESQL_KEY_FILE// }" ]] && [[ -n "${POSTGRESQL_CERTIFICATE_FILE// }" ]] \
          && [[ -n "${POSTGRESQL_CA_FILE// }" ]] && [[ -n "${POSTGRESQL_CRL_FILE// }" ]]; then

        printf "\n%-80s\n" "## Provision PostgreSQL SSL Files ###########"
        create_postgresql_secret
        PG_TEMPLATE_NAME="odie-db-stig"
      fi

      oc_create_from_template "$(get_template_location ${PG_TEMPLATE_NAME}.yaml)" "$(declare -p DB_PARAM)" & spin $! "Create ${PG_TEMPLATE_NAME} runtime from template"
    else
      return "${SKIPPED_CODE}"
    fi
  else
    printf "\n%-80s\n" "## Skipping deployment of PostgreSQL due to POSTGRES_IMAGE_NAME set to null ##"
  fi
}

build_amq() {
  run_cmd ${CMD_BINARY} get is broker-amq & spin $! "See if Image Stream is available"
  oc_start_build ${AMQ_NAME}-amq ${AMQ_BUILD_PATH} & spin $! "Building AMQ S2I"
}

create_amq_from_template() {
  create_amq_jks_file_secrets
  run_cmd ${CMD_BINARY} get dc/${AMQ_NAME}-amq
  if [ $? -ne 0 ]; then
    APPLICATION_NAME="${AMQ_NAME}" oc_create_from_template "$(get_template_location odie-amq.yaml)" "$(declare -p AMQ_PARAM)" & spin $! "Create amq runtime from template"
  else
    return "${SKIPPED_CODE}"
  fi
}
create_app_from_templates() {
  create_app_deployconfig_from_template & spin $! "Create runtime from template"
  create_app_route_from_template & spin $! "Create route from template"
  create_app_buildconfig_from_template & spin $! "Create build config from template"
}

create_app_deployconfig_from_template() {
  run_cmd ${CMD_BINARY} get dc/${APPLICATION_NAME}
  if [ $? -ne 0 ]; then
    if [ "${DB_PARAM[IMAGE_NAME]}" != "null" ]; then
      oc_create_from_template "$(get_template_location odie-runtime.yaml)" "$(declare -p RUNTIME_PARAM)"
    else
      oc_create_from_template "$(get_template_location odie-runtime-no-db.yaml)" "$(declare -p RUNTIME_PARAM)"
    fi
  else
    print_message ${SKIPPED_CODE} "Create runtime from template"
    return "${SKIPPED_CODE}"
  fi
}
create_app_route_from_template() {
  run_cmd ${CMD_BINARY} get route/${APPLICATION_NAME}-services-internal
  if [ $? -ne 0 ]; then
    oc_create_from_template "$(get_template_location odie-routes.yaml)" "$(declare -p ROUTE_PARAM)"
  else
    print_message ${SKIPPED_CODE} "Create route from template"
    return "${SKIPPED_CODE}"
  fi
}
create_app_buildconfig_from_template() {
  run_cmd ${CMD_BINARY} get bc/${APPLICATION_NAME}
  if [ $? -ne 0 ]; then
    oc_create_from_template "$(get_template_location odie-bc-binary.yaml)" "$(declare -p BC_PARAM)"
  else
    print_message ${SKIPPED_CODE} "Create build config from template"
    return "${SKIPPED_CODE}"
  fi
}

# https://stackoverflow.com/questions/4069188/how-to-pass-an-associative-array-as-argument-to-a-function-in-bash
# # pass assocociative array in string form to function
# print_array "$(declare -p assoc_array)"
# # inside function eval string into a new assocociative array
# eval "declare -A func_assoc_array="${1#*=}
oc_create_from_template() {
  TEMPLATE_FILE_NAME="$1"
  ENVVARS=""

  # eval string into a new assocociative array
  eval "declare -A func_assoc_array=${2#*=}"

  for i in "${!func_assoc_array[@]}"
  do
    ENVVARS="${ENVVARS} $i=${func_assoc_array[$i]}"
  done

  ${CMD_BINARY} process -f ${TEMPLATE_FILE_NAME} -p ${ENVVARS} -l app=${APPLICATION_NAME} | ${CMD_BINARY} create -f- -n ${PROJECT_NAME} >>${LOG_FILE}
}

oc_rollout_latest_db() {
  run_cmd ${CMD_BINARY} rollout latest ${APPLICATION_NAME}-postgresql --again & spin $! "Start database instance"
}

create_amq_serviceaccount() {
  oc_create_serviceaccount ${AMQ_SERVICE_ACCOUNT_NAME} & spin $! "Create Service account ${AMQ_SERVICE_ACCOUNT_NAME}"

  oc_policy_add_role_to_serviceaccount ${AMQ_SERVICE_ACCOUNT_NAME} & spin $! 'Add Policies to Service Account'
  oc_policy_add_role_to_user "view system:serviceaccount:${PROJECT_NAME}:default" & spin $! 'Add view to default project user'
  oc_policy_add_role_to_user "system:image-puller system:serviceaccount:${PROJECT_NAME}:${AMQ_SERVICE_ACCOUNT_NAME}" & spin $! 'Add image-puller role to Service Account'
}

create_eap_serviceaccount() {
  oc_create_serviceaccount ${EAP_SERVICE_ACCOUNT_NAME} & spin $! "Create Service account ${EAP_SERVICE_ACCOUNT_NAME}"

  oc_policy_add_role_to_serviceaccount ${EAP_SERVICE_ACCOUNT_NAME} & spin $! 'Add Policies to Service Account'
  oc_policy_add_role_to_user "system:image-puller system:serviceaccount:${PROJECT_NAME}:${EAP_SERVICE_ACCOUNT_NAME}" & spin $! 'Add image-puller role to Service Account'
  oc_policy_add_role_to_user "system:image-puller system:serviceaccount:${PROJECT_NAME}:default" & spin $! 'Add image-puller role to Service Account'
}

oc_create_serviceaccount() {
  run_cmd ${CMD_BINARY} get serviceaccount $1 -n ${PROJECT_NAME}
  if [ $? -ne 0 ]; then
    run_cmd ${CMD_BINARY} create serviceaccount $1 -n ${PROJECT_NAME}
  else
    return "${SKIPPED_CODE}"
  fi
}

oc_policy_add_role_to_user() {
  run_cmd ${CMD_BINARY} policy add-role-to-user $1
}

oc_policy_add_role_to_serviceaccount() {
#  ${CMD_BINARY} policy can-i serviceaccount view system:serviceaccount:${PROJECT_NAME}:${SERVICE_ACCOUNT_NAME} -q --user ${SERVICE_ACCOUNT_NA
#  if [ $? -ne 0 ]; then
    run_cmd ${CMD_BINARY} policy add-role-to-user view system:serviceaccount:${PROJECT_NAME}:$1
    run_cmd ${CMD_BINARY} policy add-role-to-user view -z $1
    run_cmd ${CMD_BINARY} policy add-role-to-user system:image-puller system:serviceaccount:${PROJECT_NAME}:$1
#  else
#    return ${SKIPPED_CODE}
#  fi
}

# app specific environment variables will be injected into the DeploymentConfig for the app
add_custom_envvars_to_dc() {
  if [[ -f ${DC_ENVVARS_FILENAME} ]]; then
    oc_create_app_secret & spin $! "Create application secret from ${DC_ENVVARS_FILENAME}"
    oc_add_secret_as_envvar_to_deploy_config & spin $! "Add secret as list of environment variables to DeploymentConfig"
  else
    exit ${SKIPPED_CODE} & spin $! "Customized environment variables for ${APPLICATION_NAME}"
  fi
}

oc_create_app_secret() {
  run_cmd ${CMD_BINARY} get secret ${APPLICATION_NAME}
  if [ $? -ne 0 ]; then
    # preserve white space between EOF and EOF
    cat << EOF > ${DC_ENVVARS_FILENAME}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${APPLICATION_NAME}
  annotations:
    description: 'Custom Environment Variables needed for the running of ${APPLICATION_NAME}'
  labels:
    app: ${APPLICATION_NAME}
type: Opaque
stringData:
EOF

    while read p; do
      [ -z "$p" ] && continue;
      # preserve white space here until line with EOF
      cat << EOF >> ${DC_ENVVARS_FILENAME}.yaml
  ${p%%=*}: '${p#*=}'
EOF
    done <${DC_ENVVARS_FILENAME}

    run_cmd ${CMD_BINARY} create -f ${DC_ENVVARS_FILENAME}.yaml
    rm ${DC_ENVVARS_FILENAME}.yaml
  else
    return ${SKIPPED_CODE}
  fi
}

# attach new secret to dc as environment variables
oc_add_secret_as_envvar_to_deploy_config() {
#  if [[ -f ${DC_ENVVARS_FILENAME} ]]; then
    run_cmd ${CMD_BINARY} env --from=secret/${APPLICATION_NAME} dc/${APPLICATION_NAME}
#  else
#    return ${SKIPPED_CODE}
#  fi
}

# app specific environment variables will be injected into the DeploymentConfig for the app
run_custom_app_script() {
  printf "\n%-80s\n" "## Checking for custom script ${APP_PATH}${APPLICATION_NAME}.sh ###########"
  if [[ -f ${APP_PATH}${APPLICATION_NAME}.sh ]]; then
    exit 0 & spin $! "Run custom script for ${APPLICATION_NAME}."
    source_custom_app_script
  else
    exit ${SKIPPED_CODE} & spin $! "Custom script for ${APPLICATION_NAME}"
  fi
}

source_custom_app_script() {
  . ${APP_PATH}${APPLICATION_NAME}.sh
}

oc_get_secret_value() {
  SECRET=$1
  SELECTOR=$2

  SECRET_VALUE=`${CMD_BINARY} get secret ${SECRET} -o template --template={{${SELECTOR}}}`
}

create_amq_jks_file_secrets() {
  run_cmd ${CMD_BINARY} get secret/${AMQ_NAME}-amq-ssl
  if [ $? -ne 0 ]; then
    run_cmd ${CMD_BINARY} secrets new ${AMQ_NAME}-amq-ssl AMQ_KEYSTORE=${AMQ_KEYSTORE_FILE} AMQ_TRUSTSTORE=${TRUSTSTORE_FILE}
    #run_cmd ${CMD_BINARY} label secret ${AMQ_NAME}-amq-ssl app="${APPLICATION_NAME}-amq-ssl"
  else
    return "${SKIPPED_CODE}"
  fi
}

create_truststore_secret() {
  run_cmd ${CMD_BINARY} get secret/${PROJECT_NAME}-truststore-password
  if [ $? -ne 0 ]; then
    run_cmd ${CMD_BINARY} secrets new ${PROJECT_NAME}-truststore-file TRUSTSTORE_FILE=${TRUSTSTORE_FILE}
    create_truststore_password_secret_from_template
  else
    return "${SKIPPED_CODE}"
  fi
}

create_truststore_password_secret_from_template() {
    oc_create_from_template "$(get_template_location odie-truststore-secret.yaml)" "$(declare -p TRUSTSTORE_PARAM)" & spin $! "Create project truststore secret from template"
}

create_eap_keystore_secret() {
  local SECRET_FULLNAME=${APPLICATION_NAME}-eap-keystore-file

  run_cmd ${CMD_BINARY} get secret/${SECRET_FULLNAME}
  if [ $? -ne 0 ]; then
    run_cmd ${CMD_BINARY} secrets new ${SECRET_FULLNAME} KEYSTORE_FILE=${KEYSTORE_FILE}
    run_cmd ${CMD_BINARY} label secret ${SECRET_FULLNAME} app="${APPLICATION_NAME}" secret="${APPLICATION_NAME}-eap"

    source ${SOURCED_SCRIPT_DIR}/${GLOBAL_CONFIG_FILE_NAME}

    oc_create_from_template "$(get_template_location odie-eap-keystore.yaml)" "$(declare -p EAP_KEYSTORE_PARAM)" & spin $! "Create application keystore secret from template"
  else
    return "${SKIPPED_CODE}"
  fi
}

create_postgresql_secret() {
  create_postgresql_secret_from_files & spin $! "Create postgresql secret with ssl files"
}

create_postgresql_secret_from_files() {
  local SECRET_FULLNAME=${APPLICATION_NAME}-postgresql-ssl-files

  run_cmd ${CMD_BINARY} get secret/${SECRET_FULLNAME}
  if [ $? -ne 0 ]; then
    run_cmd ${CMD_BINARY} secrets new ${SECRET_FULLNAME} server.key=${APP_PATH}${POSTGRESQL_KEY_FILE} server.crt=${APP_PATH}${POSTGRESQL_CERTIFICATE_FILE} root.crt=${APP_PATH}${POSTGRESQL_CA_FILE} root.crl=${APP_PATH}${POSTGRESQL_CRL_FILE}
    run_cmd ${CMD_BINARY} label secret ${SECRET_FULLNAME} app="${APPLICATION_NAME}" component="postgresql"
  else
    return "${SKIPPED_CODE}"
  fi
}

get_active_pod_name() {
  echo "" > /dev/null & spin $! "Get active pod name"
  oc_get_active_pod_name
}

oc_get_active_pod_name() {
  for i in {1..10}; do
    POD_READY=`${CMD_BINARY} describe pod --selector=app=${APPLICATION_NAME}-postgresql --selector=deploymentConfig=${APPLICATION_NAME}-postgresql  | grep "Ready[^:]" | awk '{ print $2 }'`

    if [ "True" == "${POD_READY}" ]; then
      POD_NAME=`${CMD_BINARY} describe pod --selector=app=${APPLICATION_NAME}-postgresql --selector=deploymentConfig=${APPLICATION_NAME}-postgresql  | grep "^Name:" | awk '{ print $2; }'`
      break;
    fi
    printf "Pod not ready, wait 15 seconds\n"
    sleep 15;
  done
}

is_project_properties_available() {
  if [[ -f ${VARIABLE_OVERRIDE_FILE} ]]; then
    return 0
  else
    return 1
  fi
}

parse_build_properties_to_envvars() {
  if [[ -f ${VARIABLE_OVERRIDE_FILE} ]]; then
      while read p; do
        # ignore empty lines and lines that start with a hash
        [ -z "$p" ] && continue;
        [ "${p:0:1}" == "#" ] && continue;
        varname=${p%%=*}
        varvalue=${p#*=}

        # prefer the arguments coming in from the env
        actual=$(echo ${!varname})
        [  ! -z "$actual" ] && continue;

        # create dynamic envvar
        export $varname=$varvalue
      done <${VARIABLE_OVERRIDE_FILE}
    fi
}

get_template_location() {
  local TEMPLATE_FILE_NAME=${APP_PATH}templates/$1

  if [[ -f ${TEMPLATE_FILE_NAME} ]]; then
    echo ${TEMPLATE_FILE_NAME}
  else
    echo ${BASE_TEMPLATE_DIR}/${1}
  fi
}
#############################################################################
# Custom messages that get shown when this script is loaded
# Additional messages called at the top of this script
#############################################################################
run_cmd exit 0 & spin $! "Custom OpenShift functions loaded"

if [[ -f ${PROJECT_PATH}${GLOBAL_CONFIG_FILE_NAME} ]]; then
  # can't print error message in function because it will get captured by the
  run_cmd exit 0 & spin $! "Using customized project app_config.cfg"
  # "source $(varname)" code so running it when this code loads
else
  run_cmd exit 0 & spin $! "Not using customized project app_config.cfg"
fi
if [[ -n "${APP_PATH}" && -f ${APP_PATH}${GLOBAL_CONFIG_FILE_NAME} ]]; then
  # can't print error message in function because it will get captured by the
  run_cmd exit 0 & spin $! "Using customized application app_config.cfg"
  # "source $(varname)" code so running it when this code loads
fi
is_oc_command_available
is_oc_logged_in
#############################################################################
# End custom messages
#############################################################################
