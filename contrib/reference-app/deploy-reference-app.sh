#!/bin/bash
set -e
# This script is a simple way to build & redeploy the Reference app on OCP
cd /opt/odie/src/contrib/reference-app
mvn clean install
mv target/reference-app.war ../../example_layout/projects/reference-project/apps/reference-app/build/reference-app/deployments/reference-app.war
oc start-build reference-app --from-dir=/opt/odie/src/example_layout/projects/reference-project/apps/reference-app/build/reference-app --wait --follow
