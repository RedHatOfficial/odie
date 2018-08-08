#!/bin/bash
set -o pipefail
###############################################################################
# OpenShift v3 application start build script
#
# Author:    nrevo
# Date:      2017-06-08
# Usage:     ./start-build.sh -n app-name -d /path/to/deployment/files
# Example:  ./start-build -n app -a /tmp/app-archive.tgz
# Comments:
#
#
#############################################################################
BASEDIR=$(dirname "$(readlink -f $0)")
source $BASEDIR/utils.sh
source $BASEDIR/openshift.sh

if is_project_properties_available; then
  printf "\n%-80s\n" "## Using build.properties ###########"
  parse_build_properties_to_envvars
  FROM_ARG_NAME="--from-dir"
  FROM_ARG_VALUE="${APPLICATION_NAME}"
# Requires 2 arguments
elif [ $# == 4 ]; then
  printf "\n%-80s\n" "## NOT Using build.properties ###########"
  PROJECT_NAME=$1
  APPLICATION_NAME=$2
  shift 2
  # Process arguments
  process_args $@
  BUILD_PATH="${FROM_ARG_VALUE}"
else
  echo -e "\nUsage:"
  printf "%-20s%s" "<project_name>" "REQUIRED: Project name as the first argument"
  echo ""
  printf "%-20s%s" "<application_name>" "REQUIRED: Application name as the second argument"
  echo ""
  usage
  echo "Example: $BASEDIR/start-build.sh smoketest jboss-helloworld-mdb --from-dir $BASEDIR/fielding_kit_reference/helloworld-mdb/"
  exit 1
fi

if [[ -z $FROM_ARG_VALUE ]]; then
  echo "To start a build, please provide a deployable type and the path to the location."
  usage
  exit 1
fi

eval $(get_app_config_file)

printf "\n%-80s\n" "## Start binary builds ###########"
start_build

#oc_get_route
