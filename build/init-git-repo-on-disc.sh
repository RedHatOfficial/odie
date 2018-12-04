#!/bin/bash
export DIR=${1:-"`pwd`/output/odie-ocp-installer.git"}
echo $DIR
mkdir -p ${DIR}
git init --bare ${DIR}
git remote remove dist || echo 0
git remote add dist ${DIR}
git push --tags dist HEAD:master
