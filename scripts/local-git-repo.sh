#!/bin/bash
DIR="`pwd`/output/odie-ocp-installer.git"
mkdir -p ${DIR}
git init --bare ${DIR}
git remote add dist ${DIR}
git push --tags dist HEAD:master
