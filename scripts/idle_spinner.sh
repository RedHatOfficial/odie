#!/bin/bash
# This script will run indefinitely until explicitly terminated

. $( dirname $0 )/lib.sh

MESSAGE=" => $1"

PPPID=$(ps -o ppid $PPID | tail -1)

function happy_exit {
  print_message 0 "$MESSAGE"
  exit 0
}


function sad_exit {
  print_message 210 "$MESSAGE"
  exit 0
}

trap happy_exit INT ALRM HUP
trap sad_exit TERM

printf -v stars '%*s' ${#MESSAGE} ''

spin='-\|/'
i=0

while true
do
  if [[ ${INTERACTIVE} = 1 ]]; then
    printf "%-70s" "$MESSAGE"
    printf "[ ]\b"
    i=$(( (i+1) %4 ))
    printf "\b${spin:$i:1}"
    printf "\r"
  fi 
  sleep .1

  # check whether the grandparent PID is still running to prevent infinite loop
  # on CTRL+C
  kill -0 ${PPPID} 2>/dev/null; [[ "$?" = 1 ]] && exit 1
done
