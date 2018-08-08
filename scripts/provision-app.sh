#!/bin/bash
set -o pipefail
###############################################################################
# OpenShift v3 application provisioning script
#
# Author:    nrevo
# Date:      2017-06-08
# Usage:     ./provision_app.sh project_name application_name
# Example:   ./provision_app.sh odie-project app
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
  # Requires 7 arguments
elif [ $# == 5 ]; then
  printf "\n%-80s\n" "## NOT Using build.properties ###########"
  PROJECT_NAME=$1
  APPLICATION_NAME=$2
  KEYSTORE_FILE=$3
  KEYSTORE_PASSWORD=$4
  KEYSTORE_ALIAS=$5
else
  echo -e "\nUsage:"
  printf "%-20s%s" "<project_name>" "REQUIRED: Project name as the first argument"
  echo ""
  printf "%-20s%s" "<application_name>" "REQUIRED: Application name as the second argument"
  echo ""
  printf "%-20s%s" "<java-keystore-file>" " REQUIRED: Location of the Java Keystore File containing the private/public certificate entry as the third argument"
  echo ""
  printf "%-20s%s" "<java-keystore-file-password>" " REQUIRED: Password for the Java Keystore File specified by the <java-keystore-file> as the fourth argument"
  echo ""
  printf "%-20s%s" "<java-keystore-alias>" " REQUIRED: Alias for the private/public certificate entry in the Java Keystore File specified by the <java-keystore-file> as the fifth argument"
  echo ""
  # printf "%-20s%s" "<postgresql-key-file>" " REQUIRED: Location of the PEM File containing the key as the sixth argument"
  # echo ""
  # printf "%-20s%s" "<postgresql-certificate-file>" " REQUIRED: Location of the PEM File containing the x509 certificate as the seventh argument"
  # echo ""
  # printf "%-20s%s" "<postgresql-ca-file>" " REQUIRED: Location of the PEM File containing the CA certificate as the eigth argument"
  # echo ""
  # printf "%-20s%s" "<postgresql-crl-file>" " REQUIRED: Location of the PEM File containing the CRL's' as the nineth argument"
  # echo ""
  echo ""
#  echo "Example: $BASEDIR/provision-app.sh smoketest jboss-helloworld-mdb $BASEDIR/fielding_kit_reference/example_ca/jboss-helloworld-mdb.lab.iad.consulting.redhat.com.jks 'eapPassword' jboss-helloworld-mdb-entry server.key server.crt root.crt root.crl"
  echo "Example: $BASEDIR/provision-app.sh smoketest jboss-helloworld-mdb $BASEDIR/fielding_kit_reference/example_ca/jboss-helloworld-mdb.lab.iad.consulting.redhat.com.jks 'eapPassword' jboss-helloworld-mdb-entry"
  exit 1
fi

eval $(get_app_config_file)

printf "\n%-80s\n" "## Verify provided keystores password/s are correct ###########"
test_jks_password $KEYSTORE_FILE $KEYSTORE_PASSWORD

printf "\n%-80s\n" "## Provision PostgreSQL Database ###########"
create_db_from_template

printf "\n%-80s\n" "## Provision Application ###########"
create_app_from_templates

printf "\n%-80s\n" "## Execute app build customizations ###########"
add_custom_envvars_to_dc
run_custom_app_script

printf "\n%-80s\n" "## Provision EAP SSL Files ###########"
create_eap_keystore_secret
