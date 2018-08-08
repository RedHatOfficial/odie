#!/bin/bash

echo "####################################################"
echo " MAKE SURE YOU ARE LOGGED IN:"
echo " $ oc login http://console.your.openshift.com"
echo "####################################################"


REGISTRY_URL="$1"


PROJECT_SUFFIX=
if [ ! -z "$2" ]; then
  PROJECT_SUFFIX="-$2"
fi

oc new-project dev$PROJECT_SUFFIX --display-name="Tasks - Dev"
oc new-project stage$PROJECT_SUFFIX --display-name="Tasks - Stage"
oc new-project cicd$PROJECT_SUFFIX --display-name="CI/CD"

sleep 2

oc policy add-role-to-user edit system:serviceaccount:cicd$PROJECT_SUFFIX:jenkins -n dev$PROJECT_SUFFIX
oc policy add-role-to-user edit system:serviceaccount:cicd$PROJECT_SUFFIX:jenkins -n stage$PROJECT_SUFFIX


oc create -f jenkins-ephemeral-template.json -n openshift

sleep 2

oc process -f cicd-template.yaml --param REGISTRY_URL=${REGISTRY_URL} --param DEV_PROJECT=dev$PROJECT_SUFFIX --param STAGE_PROJECT=stage$PROJECT_SUFFIX -n cicd$PROJECT_SUFFIX | oc create -f - -n cicd$PROJECT_SUFFIX

oc env dc/jenkins MAVEN_SLAVE_IMAGE=${REGISTRY_URL}/openshift3/jenkins-slave-maven-rhel7 -n cicd$PROJECT_SUFFIX


oc scale dc/sonarqube --replicas=0 --timeout=1m -n cicd$PROJECT_SUFFIX
oc scale dc/postgresql-sonarqube --replicas=1 --timeout=1m -n cicd$PROJECT_SUFFIX

oc scale dc/postgresql-sonarqube --replicas=0 --timeout=1m -n cicd$PROJECT_SUFFIX
echo "waiting 1m for postgresql to launch.."
sleep 60

oc scale dc/sonarqube --replicas=1 --timeout=1m -n cicd$PROJECT_SUFFIX
