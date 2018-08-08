#!/bin/bash
set -o pipefail
###############################################################################
# OpenShift v3 project provisioning script
#
# Author:    nrevo
# Date:      2017-06-08
# Usage:     ./provision-project.sh project_name
# Example:   ./provision_app.sh odie-project
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
  # Requires 2 arguments
elif [ $# == 5 ]; then
  printf "\n%-80s\n" "## NOT Using build.properties ###########"
  PROJECT_NAME=$1
  AMQ_KEYSTORE_FILE=$2
  AMQ_KEYSTORE_PASSWORD=$3
  TRUSTSTORE_FILE=$4
  TRUSTSTORE_PASSWORD=$5
else
  echo -e "\nUsage:"
  printf "%-20s%s\n" "<project_name>" "REQUIRED: Project name as the first argument"
  echo ""
  printf "%-20s%s" "<java-keystore-file>" " REQUIRED: Location of the Java Keystore File ccontaining the private/public certificate entry as the second argument"
  echo ""
  printf "%-20s%s" "<java-keystore-file-password>" " REQUIRED: Password for the Java Keystore File specified by the <java-keystore-file> as the third argument"
  echo ""
  printf "%-20s%s" "<java-truststore-file>" " REQUIRED: Location of the Java Keystore File containing the public certificates as the fourth argument"
  echo ""
  printf "%-20s%s" "<java-truststore-file-password>" " REQUIRED: Password for the Java Keystore File specified by the <java-truststore-file-file> as the fifth argument"
  echo ""
  echo ""
  echo "Example: $BASEDIR/provision-project.sh smoketest $BASEDIR/fielding_kit_reference/example_ca/broker-amq-ssl.jks 'brokerPassword' $BASEDIR/fielding_kit_reference/example_ca/trusts.jks 'trustsPassword'"
  exit 1
fi

eval $(get_app_config_file)

# Process arguments (aka variables) from the provided config file
process_args $@

printf "\n%-80s\n" "## Verify provided keystores password/s are correct ###########"
test_jks_password $AMQ_KEYSTORE_FILE $AMQ_KEYSTORE_PASSWORD
test_jks_password $TRUSTSTORE_FILE $TRUSTSTORE_PASSWORD

set_project

printf "\n%-80s\n" "## Provision Project ###########"
create_eap_serviceaccount

printf "\n%-80s\n" "## Provision Project Truststore Secret ##########"
create_truststore_secret

printf "\n%-80s\n" "## Provision AMQ Broker ###########"
create_amq_serviceaccount
create_amq_from_template

if [[ -z "${SKIP_S2I_BUILD}" ]]; then
  printf "\n%-80s\n" "## Start AMQ Broker Build ###########"
  build_amq
fi
