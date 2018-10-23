#!/bin/bash
###############################################################################
# Various script utilities
# Author:    nrevo
# Date:      2017-06-08
# Comments:
#########################################################################

# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script/27875395#27875395
prompt_yn() {
  #/bin/sh
  printf "$1"
  old_stty_cfg=$(stty -g)
  stty raw -echo
  answer=$( while ! head -c 1 | grep -i '[ny]' ;do true ;done )
  stty $old_stty_cfg
  if echo "$answer" | grep -iq "^y" ;then
      return 0
  else
      return 1
  fi
}

usage() {
  #echo -e "\nUsage:"
  echo -e "Only use ${light_green}one${normal} of the following options."
  printf "%-20s%s\n" "-a | --from-archive" "Deploy archive with contents in specific folders, only one --from argument."
  printf "%-20s%s\n" "-d | --from-dir" "Deploy directory in same layout as archive"
  printf "%-20s%s\n" "-f | --from-file" "Deploy file"
}

# Use -gt 1 to consume two arguments per pass in the loop (e.g. each
# argument has a corresponding value to go with it).
# Use -gt 0 to consume one or more arguments per pass in the loop (e.g.
# some arguments don't have a corresponding value to go with it such
# as in the --default example).
# note: if this is set to -gt 0 the /etc/hosts part is not recognized ( may be a bug )
process_args() {
  while [[ $# -gt 1 ]]
  do
  key="$1"
#  echo "key: $1"
#  echo "value: $2"

    case $key in
        -a|--from-archive)
        FROM_ARG_NAME="--from-archive"
        FROM_ARG_VALUE="$2"
        shift # past argument
        ;;
        -f|--from-file)
        FROM_ARG_NAME="--from-file"
        FROM_ARG_VALUE="$2"
        shift # past argument
        ;;
        -d|--from-dir)
        FROM_ARG_NAME="--from-dir"
        FROM_ARG_VALUE="$2"
        shift # past argument
        ;;
        --default)
        DEFAULT=YES
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
  done
}
