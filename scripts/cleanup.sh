#!/bin/bash
set -o pipefail
###############################################################################
# OpenShift v3 application cleanup script
#
# Author:    nrevo
# Date:      2017-07-01
# Usage:     ./cleanup.sh project_name application_name
# Example:   ./provision_app.sh odie-project app
# Comments:
#
#
#############################################################################
# scriptfu to create envvar pointing at the directory the running script lives in.
# https://stackoverflow.com/questions/192292/bash-how-best-to-include-other-scripts
RUN_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${RUN_DIR}" ]]; then RUN_DIR="$PWD"; fi

source "${RUN_DIR}/lib/colors.sh"
source "${RUN_DIR}/lib/spinner.sh"
source "${RUN_DIR}/lib/utils.sh"
source "${RUN_DIR}/lib/openshift.sh"

# Requires 2 arguments
if [ $# == 2 ]; then
  PROJECT_NAME=$1
  APPLICATION_NAME=$2
  source $(get_app_config_file)
else
  echo -e "\nUsage:"
  printf "%-20s%s" "<project_name>" "REQUIRED: Project name as the first argument"
  echo ""
  printf "%-20s%s" "<application_name>" "REQUIRED: Application name as the second argument"
  echo ""
  echo "Example: /provision_app.sh odie-project app"
  exit 1
fi

is_oc_command_available
is_oc_logged_in

set_project

oc delete all -l app=${APPLICATION_NAME} -n $(PROJECT_NAME) & spin $! "Delete ${APPLICATION_NAME} artifacts"
oc delete all -l app=${APPLICATION_NAME}-postgresql -n $(PROJECT_NAME) & spin $! "Delete ${APPLICATION_NAME}-postgresql artifacts"
oc delete pvc/${APPLICATION_NAME}-postgresql -n $(PROJECT_NAME) & spin $! "Delete ${APPLICATION_NAME} pvc's"
oc delete pvc/${APPLICATION_NAME}-persistent-storage -n $(PROJECT_NAME) & spin $! "Delete ${APPLICATION_NAME}-postgresql pvc's"
oc delete secret/${APPLICATION_NAME} -n $(PROJECT_NAME) & spin $! "Delete ${APPLICATION_NAME} secrets"
oc delete secret/${APPLICATION_NAME}-postgresql -n $(PROJECT_NAME) & spin $! "Delete ${APPLICATION_NAME}-postgresql secrets"
