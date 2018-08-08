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

# Takes is a JKS keystore as the first argument, and the keystore alias as the
# second. It then attempts a keytool -list command with the provided information
# and if it fails, throws an error
test_jks_password() {
  TEST_KEYSTORE=$1
  TEST_KEYSTORE_PASSWORD=$2
  # Confirm that the password provided, TEST_KEYSTORE_PASSWORD is the correct
  #   password for the TEST_KEYSTORE Java Keystore file
  JKS_OUTPUT=$(keytool -list -keystore $TEST_KEYSTORE -storepass $TEST_KEYSTORE_PASSWORD)
  if [ $? -ne 0 ]; then
    printf "${red}[Error]${normal} the password provided for $TEST_KEYSTORE is incorrect\n"
    exit 1
  fi
  # Check to see if the TEST_KEYSTORE contains at least one PrivateKeyEntry,
  #   if it doesn't we assume it is fine since it's probably just a Truststore
  GREP_OUTPUT=$(keytool -list -keystore $TEST_KEYSTORE -storepass $TEST_KEYSTORE_PASSWORD | grep -m 1 'PrivateKeyEntry')
  if [ $? -eq 0 ]; then
    # Confirm that the TEST_KEYSTORE provided contains only one PrivateKeyEntry
    #   This is required as many products don't support multiple and it's generally
    #   a best practice to have a keystore only contain one
    GREP_OUTPUT_ALL=$(keytool -list -keystore $TEST_KEYSTORE -storepass $TEST_KEYSTORE_PASSWORD | grep 'PrivateKeyEntry')
    if [ "$GREP_OUTPUT" != "$GREP_OUTPUT_ALL" ]; then
      printf "${red}[Error]${normal} the keystore provided, $TEST_KEYSTORE containes more than one PrivateKeyEntry\n"
      exit 1
    else
      # This checks to see if the key's password matches the keystore's password
      #   This is needed as neither AMQ or EAP support Java Keystores in which
      #   they are different
      # Since this next logical block is going to have to make a change to the
      #   keystore file as part of the test, a temporary copy of the keystore is
      #   going to be made
      ALIAS=$(echo $GREP_OUTPUT | cut -d, -f1)
      TMP_TEST_KEYSTORE=$(mktemp)
      cp $TEST_KEYSTORE $TMP_TEST_KEYSTORE
      JKS_OUTPUT=$(keytool -keypasswd -keystore $TMP_TEST_KEYSTORE -storepass $TEST_KEYSTORE_PASSWORD -alias $ALIAS -keypass $TEST_KEYSTORE_PASSWORD -new $TEST_KEYSTORE_PASSWORD)
      rm -f $TMP_TEST_KEYSTORE
      if [ $? -ne 0 ]; then
        printf "${red}[Error]${normal} the keystore provided, $TEST_KEYSTORE, has a password for the entry $ALIAS that does not match the keystore's storepass\n"
        exit 1
      fi
    fi
  fi
}
