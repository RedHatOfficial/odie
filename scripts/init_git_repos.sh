#!/bin/bash

# Interactive Git Setup
# mbattles@redhat.com
#	
# This script will guide a user through configuration of their local Git 
# repo - include SSH keys, remotes, and the media repo.
#
# You can override these env variables if desired:

GITLAB_PRIVATE_KEY=${GITLAB_PRIVATE_KEY:-~/.ssh/odie_key}
ODIE_GIT_REPO=${ODIE_GIT_REPO:-/opt/odie/src/}

set +e
BASEDIR=$(dirname "$0")
. ${BASEDIR}/lib.sh

function git_host_auth() {
  KEY=$1
  HOST=$2
  URL=$3
  
  if [[ ! -f "${KEY}" ]]; then
    confirmation_prompt 0 "SSH Key ${KEY} does not exist.  Press Y to create or N to exit: "
    ssh-keygen -f ${KEY}
  fi


  cat >>~/.ssh/config <<EOF
Host ${HOST}
RSAAuthentication yes
IdentityFile ${KEY}
EOF
  chmod 600 ~/.ssh/config

  echo "Goto ${URL} and add this key:"
  echo
  cat ${KEY}.pub
  echo
  confirmation_prompt 1 "Continue (y/n) "
}


function git_add_remote() {
  cd ${ODIE_GIT_REPO}
  set +x
  git remote add ${1} ${2}
}


echo
echo "${bold}Please enter Y or N for all prompts${normal}"
echo

( confirmation_prompt 1 "Do you want to setup your Git author info (name & email)? " )
if [[ "$?" = 0 ]];  then
  read -p "Enter your name to appear in Git commits: " GIT_NAME
  git config --global user.name "${GIT_NAME}"

  read -p "Enter the email to appear in git commits: " GIT_EMAIL
  git config --global user.email "${GIT_EMAIL}"
fi


echo
( confirmation_prompt 1 "Do you want to setup a SSH Host key to authenticate to Red Hat Gitlab? " )
if [[ "$?" = 0 ]];  then
  git_host_auth ${GITLAB_PRIVATE_KEY} "gitlab.consulting.redhat.com" "https://gitlab.consulting.redhat.com/profile/keys"
fi

echo
( confirmation_prompt 1 "Do you want to add Red Hat GitLab as a remote git repository? " )
if [[ "$?" = 0 ]];  then
  git_add_remote "gitlab" "ssh://git@gitlab.consulting.redhat.com:2222/af-org-ocp/odie-ocp-installer.git"
fi
