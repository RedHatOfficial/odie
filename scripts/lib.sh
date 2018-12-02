#!/bin/bash
# only let this file be sourced once
[[ "$0" = "$BASH_SOURCE" && ! -z ${INSTALLER_VERSION} ]] && return
set -o pipefail

export BASEDIR=$(dirname "$(readlink -f "$0")")
export CONTENT_DIR="${BASEDIR}"
export OUTPUT_DIR=${OUTPUT_DIR:-/opt/odie}
export KICKSTART=${KICKSTART:-0}
export GIT_CLONE=${OUTPUT_DIR}/src
export VERSION_SH=${OUTPUT_DIR}/src/scripts/odie-version.pl
export CONTRIB_BIN=${GIT_CLONE}/contrib/bin
export CONFIG_DIR=${ODIE_CONFIG_DIR:-${OUTPUT_DIR}/config}
export EXPORT_DIR=${ODIE_EXPORT_DIRECTORY:-${OUTPUT_DIR}/exports}
export PROJECTS_DIR=${ODIE_PROJECT_DIRECTORY:-${OUTPUT_DIR}/projects}
export UPDATES_DIR=${ODIE_PLAYBOOK_UPDATES_DIRECTORY:-${OUTPUT_DIR}/src/playbooks/updates}
export IMAGES_DIR=${ODIE_IMAGES_DIRECTORY:-${OUTPUT_DIR}/images}
export TARGET=master
export LOG_NAME=/tmp/odie.log-`date +%y%m%d-%H%M%S`
export INTERACTIVE=${INTERACTIVE:-1}
export LOG_FILE="${LOG_FILE:-${LOG_NAME}}"
export CMD_SUFFIX=" 2>&1 >>${LOG_FILE}"

export SHOW_TAIL=${SHOW_TAIL:-0}
export SPIN_FPS=${SPIN_FPS:-.1}

VERSION_FILE=${CONTENT_DIR}/INSTALLER_VERSION
CONTENT_VERSION=$(cat ${VERSION_FILE} 2> /dev/null)

${VERSION_SH} set content ${CONTENT_VERSION}

export INSTALLER_VERSION=${CONTENT_VERSION}
export INSTALLED_VERSION=$( ${VERSION_SH} show active )
export UPGRADE_VERSION=$(if [[ $(${VERSION_SH} compare active content) = -1 ]]; then echo 1; else echo 0; fi )

export OCP_VERSION=$(cat ${CONTENT_DIR}/OCP_VERSION 2>/dev/null)

function confirmation_prompt() {
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script/27875395#27875395
  RETURN=${1}
  shift
  MSG="$*"
  while true; do
    read -p "${MSG}" yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) exit $RETURN;;
      * ) echo "Please answer yes or no.";;
    esac
  done
}

###############################################################################
# Fancy Spinner function borrowed from stackoverflow
# url: https://stackoverflow.com/questions/12498304/using-bash-to-display-a-progress-working-indicator
# Author:    nrevo
# Date:      2017-06-08
# Usage:     any_command & spin $! "Optional Text... -"
# Examples:  sleep 3 & spin $!
#            sleep 3 & spin $! "Sleeping: []"
# Comments:  dollarsign bang returns the Process Id of the previous running command.
#     This function only works on a backgrounded command and has to be called
#     as the next command or the correct pid is passed as the first argument
#     The second argument is a string to print where the last character is the spinner
#########################################################################
SKIPPED_CODE=200
FAILURE_CODE=210
COMPLETE_CODE=230

# https://stackoverflow.com/questions/356100/how-to-wait-in-bash-for-several-subprocesses-to-finish-and-return-exit-code-0
spin() {
  printf -v stars '%*s' ${#2} ''
  echo >> ${LOG_FILE}
  echo "$2"  >> ${LOG_FILE}
  echo "${stars// /*}" >> ${LOG_FILE}
  echo >> ${LOG_FILE}

  if [ -n "$1" ]; then
    spin='-\|/'
    i=0

    while kill -0 $1 2>>/dev/null
    do
       if [[ ${INTERACTIVE} = 1 ]]; then
          printf "%-70s" "$2"
          printf "[ ]\b"
          i=$(( (i+1) %4 ))
          printf "\b${spin:$i:1}"
          printf "\r"
      fi
      sleep ${SPIN_FPS}
    done
    # $? after the while loop is the return code of the kill command.  absolutely useless here
    wait $1 # https://stackoverflow.com/questions/1570262/shell-get-exit-code-of-background-process
    return_code=$?
#    echo "return_code: ${return_code}"
    print_message ${return_code} "$2"
  fi
}


function complete_message() {
  echo
  print_message ${COMPLETE_CODE} "$1"
  echo
}

function print_message() {
  rc="$1"
  echo -en "\r" # https://stackoverflow.com/questions/2388090/how-to-delete-and-replace-last-line-in-the-terminal-using-bash
  printf "%-70s" "$2"
  printf "[ ]\b"

  if [[ $rc == "0" ]]; then
    # https://stackoverflow.com/questions/8903239/how-to-calculate-time-difference-in-bash-script
#    printf "\b${light_green}`date -u -d @"$SECONDS" +'%_Mm %_Ss'`${normal}]\n"
    printf "\b${light_green}$(date +%H:%M:%S)${normal}]\n"
  elif [[ $rc == "${SKIPPED_CODE}" ]]; then
    printf "\b${light_blue}SKIPPED${normal}]\n"
  elif [[ $rc == "${FAILURE_CODE}" ]]; then
    printf "\b${light_green}COMPLETE${normal}]\n"
  elif [[ $rc == "${COMPLETE_CODE}" ]]; then
    printf "\b${light_green}${underline}SUCCESS${normal}]\n"
  else
    printf "\b${red} ERROR ${normal}]\n"
    if [[ ${INTERACTIVE} = 1 ]]; then
        {
        echo;
        echo "${bold}${red} LOG TAIL  *******************************************${normal}"
        tail  ${LOG_FILE}
        echo; confirmation_prompt 1 "${bold}${red}****** ${normal} Do you want to view the entire error log (y/n): "; less ${LOG_FILE}; exit $rc ; }
    else
        tail -25 ${LOG_FILE} >> /dev/stderr
    fi

    exit 1
    #return $((rc + 0))
  fi
  return $((rc + 0))
}

###############################################################################
# https://unix.stackexchange.com/questions/9957/how-to-check-if-bash-can-print-colors
# http://misc.flogisoft.com/bash/tip_colors_and_formatting
# https://en.wikipedia.org/wiki/ANSI_escape_code
# Sets up color support if available
# Author:    nrevo
# Date:      2017-06-08
# Comments:
#########################################################################
test_tty_colors() {
  printf "${red}error${normal}\n"
  printf "${green}success${normal}\n"
}

tty_supports_color() {
  # check if stdout is a terminal...
  if test -t 1; then
    # see if it supports colors...

    ncolors=$(tput colors)
    if test -n "$ncolors" && test $ncolors -ge 8; then
      return 0
    else
      return 1
    fi
  fi
}

if [ tty_supports_color ]; then
  bold="$(tput bold)"
  underline="$(tput smul)"
  standout="$(tput smso)"
  normal="$(tput sgr0)"
  black="$(tput setaf 0)"
  red="$(tput setaf 1)"
  green="$(tput setaf 2)"
  yellow="$(tput setaf 3)"
  blue="$(tput setaf 4)"
  magenta="$(tput setaf 5)"
  cyan="$(tput setaf 6)"
  white="$(tput setaf 7)"
  # https://en.wikipedia.org/wiki/ANSI_escape_code
  light_green='\033[1;32m'
  light_blue='\033[1;34m'
  NC='\033[0m' # No Color
fi

function run_cmd() {
  CMD_SUFFIX="2>&1 | tee -a ${LOG_FILE}"
  if [[ "$SHOW_TAIL" = "0" ]]; then
    CMD_SUFFIX="${CMD_SUFFIX} >/dev/null"
  fi

  CMD=${@}
  eval echo "$ ${CMD}" ${CMD_SUFFIX}
  eval ${CMD} ${CMD_SUFFIX}
  return $?
}



IDLE_PID=

noop() {
  echo "NOOP"
}
kill_idler() {
  trap noop HUP ALRM TERM
  if [[ "$1" = 0  ]] ; then
    killall -q -s SIGALRM -w idle_spinner.sh
  else
    killall -q -s SIGTERM -w idle_spinner.sh
  fi
}

function run_ansible_play() {
  PLAY_START_TIME=$SECONDS # Magic bash variable
  MSG="${1}"

  CMD="${@:2}"

  print_message 0 "Playbook Started: ${MSG}"
  eval echo "$ ${CMD}" "${CMD_SUFFIX}"

  SHOW_TASKS=0

  if [[ ${SHOW_TAIL} = 1 ]]; then
    run_cmd ${CMD}
    return $?
  fi

  set -o pipefail
  ${CMD} 2>&1 | tee -a ${LOG_FILE} |  while read -r line ; do

#    if [[ "${line}" = *"fatal"* ]] ; then
#      kill_idler 1
#      continue
#    fi

    if [[ "${SHOW_TASKS}" = 1 && "${line}" != "PLAY"* && "${line}" != "TASK"* ]] ; then
      # TODO: skip steps here
      continue
    elif [[  "${SHOW_TASKS}" = 0 && "${line}" != "PLAY"* ]] ; then
      continue
    elif [[ "${line}" = *"PLAY RECAP"* ]] ; then
      continue
    else
      kill_idler 0
    fi

    PLAY=$(echo "$line" | sed -e 's/^PLAY \[\(.*\)\].*$/PLAY :: \1/' | sed -e 's/^TASK \[\(.*\)\].*$/\1/')
    echo "$MESSSAGE"  >> ${LOG_FILE}
    ${OUTPUT_DIR}/src/scripts/idle_spinner.sh "${PLAY::68}" &
    #IDLE_PID=$!
    sleep .2
  done

  RETURN="$?"
  kill_idler # in case we had invalid output / termination of the ansible-playbook command
  sleep .5 # stop the last spinner

  print_message ${RETURN} "Playbook Completed: ${MSG}"
  return $RETURN
}


remove_password_file(){
  if [[ ! -z "${ANSIBLE_VAULT_PASSWORD_FILE}" ]]; then
    echo "Removing Ansible Vault Password File (${ANSIBLE_VAULT_PASSWORD_FILE})"
    rm -rf $ANSIBLE_VAULT_PASSWORD_FILE
  fi
}

function vault_password() {
  trap remove_password_file EXIT 0 1 2 3 6
  export ANSIBLE_VAULT_PASSWORD_FILE=$(mktemp)
  echo -n "Ansible Vault Password: "
  read -s PASSWORD
  echo $PASSWORD > $ANSIBLE_VAULT_PASSWORD_FILE
  chmod 0600 $ANSIBLE_VAULT_PASSWORD_FILE
}

function verify_installer() {

  if [[ ! -d "${CONTENT_DIR}" ]] ; then
    echo "${red}[ERROR]${normal}: No Source content found at ${CONTENT_DIR}.  Please specify directory via ${bold}--source [DIR]${normal}" | tee -a ${LOG_FILE} >> /dev/stderr
    exit 1
  fi

  VERSION_FILE=${CONTENT_DIR}/INSTALLER_VERSION
  if [[  $? -ne 0 ]]; then
    echo "${red}[ERROR]${normal}: Could not find version file (${VERSION_FILE}).  Is ${CONTENT_DIR} a valid ODIE installation media directory?" | tee -a ${LOG_FILE}>> /dev/stderr
    exit 1
  fi

}


pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

# Detect if logged into OpenShift Container Platform (OCP) tools (oc)
is_oc_logged_in() {
  run_cmd oc whoami  & spin $! "Checking if oc command is logged in"
  if [ $? -ne 0 ]; then
    printf "${red}[Error]${normal} not logged in via the oc tool\n"
    exit 1
  fi
}
