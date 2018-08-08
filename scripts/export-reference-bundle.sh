#!/usr/bin/env bash
#
# Export the reference-project into the ODIE project and application bundles
#
# Environment Variables:
#   ODIE_PARENT_PROJECT_PATH    The location of the example project     /opt/odie/src/example_layout/projects
#   ODIE_EXPORT_DIRECTORY    The location of the output projects        output/bundles/


INSTALLER_VERSION=$(cat INSTALLER_VERSION)

export ODIE_EXPORT_DIRECTORY=${ODIE_EXPORT_DIRECTORY:-output/bundles}
export ODIE_PROJECT_DIRECTORY=${ODIE_PROJECT_DIRECTORY:-/opt/odie/src/example_layout/projects}

# This is used in the dynamic inventory script.  It should be made more consistent
export ODIE_PARENT_PROJECT_PATH=${ODIE_PROJECT_DIRECTORY}

export INTERACTIVE=0

set -e
set -x
chmod -R u+rwX,g+rX,o-rwX ${ODIE_PROJECT_DIRECTORY}
chown -R admin:admin ${ODIE_PROJECT_DIRECTORY}
rm -rf ${ODIE_EXPORT_DIRECTORIES}
mkdir -p ${ODIE_EXPORT_DIRECTORY}
./odie.sh app export reference-project --builds --output-name odie-export-reference-project-${INSTALLER_VERSION}
sleep 1
./odie.sh app export reference-project reference-app --builds --output-name odie-export-reference-project-reference-app-${INSTALLER_VERSION}
