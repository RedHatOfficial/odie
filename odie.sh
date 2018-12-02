#!/bin/bash

export BASEDIR=$(dirname "$(readlink -f "$0")")
SCRIPT_NAME=$(basename "$0")

. ${BASEDIR}/scripts/lib.sh

# SCRIPT VARIABLES
KEEP_CONTENT_DIR=1
STASH_UNCOMMITTED=0
REINIT_CONFIG=0
HARDEN_HOSTS=0
APP_UNPROVISION=0
SKIP_GIT=${SKIP_GIT:-0}
LOOP_PING=0
MAKE_CMD="make -f Makefile.ocp"

# FUNCTIONS (This is all being kept in-line to make transfer easier)


function rsync_dir() {
  DIR=$1
  OUTPUT=$2
  MSG=${@:3:99}
  run_cmd rsync -av ${DIR} ${OUTPUT}
}


function git_stash_save() {
  cd ${GIT_CLONE}
  run_cmd git stash -u -a
}

function git_stash_apply() {
  cd ${GIT_CLONE}
  run_cmd git stash apply
}

function git_fetch() {
  PULL_TARGET=$1
  cd ${GIT_CLONE}
  run_cmd git fetch file:///${CONTENT_DIR}/odie-ocp-installer.git --tags
}

function git_checkout() {
  PULL_TARGET=$1
  cd ${GIT_CLONE}
  run_cmd git checkout ${PULL_TARGET}
  run_cmd git pull file:///${CONTENT_DIR}/odie-ocp-installer.git ${PULL_TARGET}
}

function git_update() {

  if [[ "${SKIP_GIT}" = 1 ]]; then
    return
  fi

  if [[ -d "${GIT_CLONE}"  ]] ; then
    UNTRACKED=0
    cd ${GIT_CLONE}

    GIT_STATUS=$(git diff-index --quiet HEAD --)
    RES=$?
    [[ $RES -ne 0 ]] && UNTRACKED=1

    if [[ ${UNTRACKED} -eq 1 && ${STASH_UNCOMMITTED} -eq 0 ]] ; then
      cat <<EOF

  ${bold}${yellow}WARNING:${normal} - ${bold}${GIT_CLONE}${normal} repository has uncommited changes.

This installer will reset the repository (${bold}git reset --hard${normal}) However, this will
not modify your config files.  If you have uncommited files, you should not proceed and manually
commit them or use the ${bold}--stash${normal} command line option.

EOF
      confirmation_prompt 0  "		Proceed? (y/n) : "
      cd ${GIT_CLONE}
      git reset --hard
    elif [[ ${UNTRACKED} -eq 1 && ${STASH_UNCOMMITTED} -eq 1 ]]; then
      echo "${yellow}[EXPERIMENTAL]${normal}: Attempting to stash changes.  Please verify working tree is correct after proceeding."  | tee -a ${LOG_SUFFIX}
      git_stash_save & spin $! "Stashing existing changes"
    fi

    git_fetch ${TARGET} & spin $! "Fetching latest changes"
    git_checkout ${TARGET} & spin $! "Checking out ${TARGET}"

    if [[ ${UNTRACKED} -eq 1 && ${STASH_UNCOMMITTED} -eq 1 ]]; then
      git_stash_apply & spin $! "Applying existing changes"
    fi

  else
    run_cmd git clone file://${CONTENT_DIR}/odie-ocp-installer.git ${GIT_CLONE} & spin $! "Clone ODIE Installer"
  fi

}

function setup_properties() {

  BEFORE_FILE=$(mktemp)
  AFTER_FILE=$(mktemp)

  wc -l ${CONFIG_DIR}/*.yml 2>/dev/null | grep -v total > ${BEFORE_FILE}

  cd ${GIT_CLONE}

  run_ansible_play  "Update Property Files for ${INSTALLER_VERSION}" ./playbooks/generate_configuration/property_generation.yml
  SAMPLE_DIR=/opt/odie/src/contrib/env-config/

#  cp -n ${SAMPLE_DIR}/default/hosts.csv /opt/odie/config/hosts-default.csv.sample
 # cp -n ${SAMPLE_DIR}/lab/hosts.csv /opt/odie/config/hosts-lab.csv.sample
  #cp -n ${SAMPLE_DIR}/full/hosts.csv /opt/odie/config/hosts-full.csv.sample

  wc -l ${CONFIG_DIR}/*.{yml,csv} 2>/dev/null | grep -v total > ${AFTER_FILE} 2>/dev/null

  DIFF=$(diff -b ${BEFORE_FILE} ${AFTER_FILE} | grep -v total | egrep '^>'  | awk '{print $3;}')

  if [[ ! -z "${DIFF}" ]]; then
    complete_message "Property File Generation :: Updated Properties"
    cat <<PROPERTIES

  ${underline}Please review the following property files for updates${normal}:

PROPERTIES

    declare -A PROPS
    PROPS["${CONFIG_DIR}/custom.yml"]="Advanced Configuration options for sophisicated use cases"
    PROPS["${CONFIG_DIR}/odie.yml"]="Installation Parameters"
    PROPS["${CONFIG_DIR}/build.yml"]="Parameters used to build ODIE and deploy via KVM"
    PROPS["${CONFIG_DIR}/env.yml"]="Specify site centric information about your environment "
    PROPS["${CONFIG_DIR}/hosts.csv"]="Static network information and cluster topology"
    PROPS["${CONFIG_DIR}/secret.yml"]="Specifies the credentials for your default users. Encrypted via ${bold}odie encrypt${normal}"
    PROPS["${CONFIG_DIR}/certs.yml"]="Parameters used for SSL settings for the publically available OpenShift management endpoints"

     while read -r key; do
        echo "  * ${bold}${key}${normal}	- ${PROPS[$key]}"
    done <<< "${DIFF}"

  cat <<PROPERTIES





PROPERTIES
    else
    complete_message "Property File Generation :: No Changes"

    fi

    ${VERSION_SH} set properties ${INSTALLER_VERSION}
  rm ${AFTER_FILE} ${BEFORE_FILE}
}

function extract_config() {
  URL=$1
  OUT_FILE=/root/odie-config.tar.xz
  OUTPUT_DIR=${CONFIG_DIR}/
#set -x
  run_cmd wget $URL -O $OUT_FILE
  run_cmd mkdir -p ${CONFIG_DIR}
  run_cmd cd ${CONFIG_DIR}
  run_cmd tar -xvJf ${OUT_FILE}
}

function download_config() {
  SOURCE_FILE=odie-config.tar.xz
  GW_IP=$(/sbin/ip route | awk '/default/ { print $3 }')

  CONFIG_SERVER_HOST=${CONFIG_SERVER_HOST:-$GW_IP}
  URL=http://${CONFIG_SERVER_HOST}/${SOURCE_FILE} 

  RESULT=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' --connect-timeout 5 $URL)

  MSG="Download Remote Configuration from Gateway"

  if [[ $RESULT = 200 ]]; then
    run_cmd extract_config $URL ${CONFIG_DIR} & spin $! "${MSG}"
  else
    return 200 & spin $! "${MSG}"
  fi
}

function setup() {

  run_cmd cp /opt/odie/src/conf/profile.d/odie-commands.sh /etc/profile.d/ & spin $! "Setup core bash profile"
  run_cmd cp /opt/odie/src/conf/rc/bashrc /root/.bashrc & spin $! "Setup bash rc"
  mkdir ${IMAGES_DIR}

  download_config
  setup_properties
  configure
  generate_config
  push_images

  run_cmd systemctl disable odie-setup & spin $! "Disabling ODIE setup script"

}


function setup_web_server() {

  #Generate certificate for Apache HTTPS encryption
  run_cmd openssl req -batch -x509 -nodes -days 1825 -newkey rsa:2048 -keyout /etc/pki/tls/private/localhost.key -out /etc/pki/tls/certs/localhost.crt

  ## Allow HTTPS traffic through firewall
  run_cmd firewall-cmd --permanent --add-port=443/tcp
  run_cmd firewall-cmd --permanent --add-port=80/tcp
  run_cmd firewall-cmd --reload

  run_cmd systemctl enable httpd
  run_cmd systemctl start httpd
}

function test_local_repo() {
  URL=http://localhost/repos/odie-custom/
  curl_test ${URL}
  return $?
}

function curl_test() {
  URL=$1
  run_cmd curl -s -f ${URL}
  if [[ $? -ne 0 ]] ; then
    echo "${red}[ERROR]${normal} Could not load ${URL}.  Check Apache httpd configuration.  (${bold}journalctl -u httpd.service${normal})." | tee -a ${LOG_FILE}
    return 1
  fi
}


function stage() {
  verify_installer & spin $! "Verify installation content"

  if [[ -d "${OUTPUT_DIR}" && ${KEEP_CONTENT_DIR} -eq 0 ]] ; then
    confirmation_prompt 0 "Existing content found at ${bold}${OUTPUT_DIR}${normal}.  This installer will delete that directory.  Proceed? (y/n) : "
    rm -rf ${OUTPUT_DIR}/{images,kickstart,repo} & spin $! "Deleting ${OUTPUT_DIR}"
  fi

  mkdir -p ${OUTPUT_DIR} & spin $! "Creating ${OUTPUT_DIR}"
  sleep 1

  if [[ -d "${CONTENT_DIR}/Packages" ]]; then
    rm -rf ${OUTPUT_DIR}/repo/odie-custom/repodata
    mkdir -p ${OUTPUT_DIR}/repo/odie-custom/
    run_cmd rsync -av ${CONTENT_DIR}/Packages/* ${OUTPUT_DIR}/repo/odie-custom/ & spin $! "Copying disconnected RPM repository".rpm
    run_cmd createrepo -v /opt/odie/repo/odie-custom -o /opt/odie/repo/odie-custom & spin $! "Creating RPM repo metadata"
    run_cmd ${CONTENT_DIR}/scripts/repo-pki.sh & spin $! "Signing YUM Repo"
  fi


  if [[ -d "${CONTENT_DIR}/container_images" ]] ; then
      # TODO: This should reuse the "image_source" variable
      run_cmd rsync -av ${CONTENT_DIR}/container_images/* ${OUTPUT_DIR}/images/ & spin $! "Copying Docker Images"
  fi

  if [[ -d "${CONTENT_DIR}/utilities" ]] ; then
      mkdir -rf ${OUTPUT_DIR}/utilities
      cp -r ${CONTENT_DIR}/utilities ${OUTPUT_DIR}/utilities & spin $! "Copying Support Utilities Directory"
  fi

  if [[  -d "${CONTENT_DIR}/odie-ocp-installer.git" ]] ; then
      git_update
      ${VERSION_SH} set stage ${INSTALLER_VERSION}
      echo > /etc/motd
      echo "    ODIE Release $( ${VERSION_SH} show stage)" >> /etc/motd
      echo >> /etc/motd
      ln --force -s /opt/odie/src/odie.sh /usr/bin/odie & spin $! "Symlinking odie"
      cp -nf /opt/odie/src/contrib/bin/* /usr/bin/ & spin $! "Installing 3rd Party Utilities"
  fi

  complete_message "Installation Media Staging"
  ${VERSION_SH} set stage ${INSTALLER_VERSION}
}

function generate_config() {
  pushd ${GIT_CLONE}
  rm -f inventory/inventory
  run_ansible_play "ODIE :: Generate Configuration Files" ./odie-generate.yml
  ${VERSION_SH} set configure ${INSTALLER_VERSION}

  cat <<GENERATEEOF

  This has generated the following files.

  * ${bold}${OUTPUT_DIR}/kickstart/${normal} - Kickstart files that will be used for provisioning
  * ${bold}${GIT_CLONE}/inventory/inventory${normal} - Static inventory file used for the Red Hat OCP Ansible playbooks

  ${bold}${yellow}WARNING:${normal} Any changes to these files will be overriden

GENERATEEOF

  popd
}

function configure() {
  cd ${GIT_CLONE}

  # TODO: convert all these into playbooks!!
  run_cmd setup_web_server & spin $! "Setup web server"
  run_cmd ${MAKE_CMD} import_pki & spin $! "Import Red Hat GPG Key"
  run_cmd ${MAKE_CMD} webdirs & spin $! "Creating web directories for httpd content"
  run_cmd ${MAKE_CMD} localrepos  & spin $! "Setting up local RPM repos"

  run_ansible_play  "Run Configuration" ./odie-configure.yml

  run_cmd test_local_repo & spin $! "Test local RPM Repo"
  complete_message "JumpHost Configuration"
}


function conditionally_run_play() {
  YAML="${1}"
  MSG="${2}"
  CMD="${@:3}"
  YAML_VALUE=$(./contrib/bin/yaml_linux_amd64 read /opt/odie/config/odie.yml ${YAML})
  if [[ ${YAML_VALUE} =~ [Tt]rue|1 ]]; then
    run_ansible_play "${MSG}" ${CMD}
  else
    return 200 & spin $! "${MSG}"
  fi
}


function push_images() {
  cd ${GIT_CLONE}
  run_ansible_play "Setup registry" playbooks/ocp_install/prepare_registry.yml
  run_ansible_play "Push images into Standalone Registry" ${MAKE_CMD} push
}


function install_cluster() {
  cd ${GIT_CLONE}

  run_ansible_play "Yum Clean" ${MAKE_CMD} yum_clean
  run_cmd yum -y install openshift-ansible & spin $! "Install openshift-ansible" 
  run_ansible_play "Cluster Install Steps" ./odie-install.yml
  #run_ansible_play "Installing Certificates" ${MAKE_CMD} install_certificates
  run_ansible_play "Installing OCP Cluster" ${MAKE_CMD} install_openshift
  # TODO: test all of these!!
#  conditionally_run_play deploy_cns "Install Container Native Storage (Gluster)" ${MAKE_CMD} install_gluster
#  conditionally_run_play deploy_metrics "Install Metrics Subsystem" ${MAKE_CMD} install_metrics
#  conditionally_run_play deploy_logging "Install Logging Subsystem" ${MAKE_CMD} install_logging
#  conditionally_run_play deploy_cloudforms  "Install CloudForms" ${MAKE_CMD} install_cfme
  #run_ansible_play "Configuring Jumphost Certificate" ${MAKE_CMD} admin
  #run_ansible_play "Configuring Registry Console" ${MAKE_CMD} registry_console_cert
  #run_ansible_play "Push images into OCP Registry" ${MAKE_CMD} push_ocp
  #run_ansible_play "Patch resolv.conf on Nodes" ${MAKE_CMD} patch_origin_dns
  conditionally_run_play setup_htpasswd_accounts  "Install HTPasswd authentication" ${MAKE_CMD} install_htpasswd
  # eventually add pivproxy here
  ${VERSION_SH} set install ${INSTALLER_VERSION}
  ${VERSION_SH} set ocp ${OCP_VERSION}

  if [[ "${HARDEN_HOSTS}" = 1 ]]; then
    harden_hosts
  fi

  install_footer
}

function run_update_playbooks() {
  for i in `ls ${UPDATES_DIR}` ; do
    VERSION=$(echo $i | cut -d - -f 1)
    if [[ $( ${CONTRIB_BIN}/semver compare $INSTALLED_VERSION $VERSION) = -1 ]] ; then
      BOOK=$(realpath "$UPDATES_DIR/$i")
      run_ansible_play "${i}" $BOOK
    fi
  done
}

function patch_cluster() {
  cd ${GIT_CLONE}

  run_cmd ${MAKE_CMD} yum_clean "Yum Clean"
  run_ansible_play "Updating RPMs" ./playbooks/operations/update_rpms.yml
  run_ansible_play "Push images into Standalone Registry" ${MAKE_CMD} push
  run_ansible_play "Push images into OCP Registry" ${MAKE_CMD} push_ocp
  run_update_playbooks
  ${VERSION_SH} set patch ${INSTALLER_VERSION}

  ansible all -m command -a '/usr/bin/needs-restarting -r' 2>&1 > /dev/null
  RES=$?

  if [[ "$RES" != 0 ]]; then
    cat <<EOF

  ${bold}${yellow}WARNING:${normal} -  VMs require restarting when the kernel or system libraries are updated

Press ${bold}${green}Y${normal} to reboot now. Alternatively, you can cancel and reboot later via the ${bold}odie reboot${normal} command.

EOF
      confirmation_prompt 0  "		Proceed? (y/n) : "
      echo
      reboot_hosts
  fi


  patch_footer
}


function patch_footer() {
    complete_message "OCP Cluster :: Patched"
}

function install_footer() {
    complete_message "OCP Cluster :: Installation"
}

function ping_hosts() {
  pushd ${GIT_CLONE}
  if [ "$LOOP_PING" -eq "1" ]; then
    until (INTERACTIVE=0 run_ansible_play "Pinging Hosts" ./playbooks/operations/ping.yml); do
      echo "re-ping"
    done
  else
    run_ansible_play "Pinging Hosts" ./playbooks/operations/ping.yml
  fi
  popd
}
function reboot_hosts() {
  pushd ${GIT_CLONE}
  run_ansible_play "Rebooting Hosts" ./playbooks/operations/reboot_hosts.yml

  cat <<EOF

  ${bold}[NOTE]${normal} - The hosts have been begun their shutdown procedures  Manually enter each VM via the console
      to enter its LUKS passphrase.

EOF

  confirmation_prompt 0  " When the hosts are back online, press ${green}${bold}Y${normal} to continue or press ${red}${bold}N${normal} to cancel:  "

  run_ansible_play "Verify Hosts" ./playbooks/operations/ping.yml
  popd
}
function check_install() {
  cd ${GIT_CLONE}
  cat <<EOF

  ${bold}[Note]${normal} - This step pings all the hosts to verify connectivity
  and checks each host is FIPS enabled.

EOF

  run_ansible_play "Checking ODIE Environment" ./odie-check.yml
}

function harden_hosts() {
  cd ${GIT_CLONE}
  cat <<EOF

  ${bold}[CAUTION]${normal} - The installer will disable the SSH key login and
              you will now be prompted for the password of the ${bold}admin${normal} user.

              There may be multiple password prompts throughout the installation process.

EOF
  confirmation_prompt 0 "  Proceed? (y/n) : "
  echo

  # this needs to be executed independently since subseqent commands will need to be prompted
  run_ansible_play "Install pivproxy" ./playbooks/security/install_pivproxy.yml
  run_ansible_play "Configure roles for pivproxy" ./playbooks/security/configure_pivproxy_roles.yml
  run_ansible_play "Securing Ansible Configuration" ./playbooks/security/update_ansible_cfg.yml
  run_ansible_play "Securing ODIE Environment" ./odie-harden.yml

  complete_message "OCP Cluster :: Hardened (FIPS + DISA STIG)"
  ${VERSION_SH} set harden ${INSTALLER_VERSION}

  cat <<EOF

  ${bold}${blue}[NOTE]${normal} - The hosts have been STIG'd but the hosts must be restarted.

      Please press ${bold}${green}Y${normal} to reboot now, or ${bold}${red}N${normal} to cancel and manually restart.

  ${bold}[CAUTION]${normal} - The JumpHost should be manually restarted after this procedure.

EOF
  confirmation_prompt 0 "  Restart cluster? (y/n): "
  echo

  reboot_hosts

  cat <<EOF
EOF
}

function validate_hosts() {
  cd ${GIT_CLONE}
  run_ansible_play "Validate reference-project installation" ./odie-validate.yml
}

function install_pivproxy() {
  cd ${GIT_CLONE}
  run_ansible_play "Install PIV Proxy" ./playbooks/security/install_pivproxy.yml -e install_piv_proxy=true
}

function update_pivproxy() {
  cd ${GIT_CLONE}
  run_ansible_play "Update PIV Proxy" ./playbooks/security/update_pivproxy.yml
}

function ldap_group_sync() {
  cd ${GIT_CLONE}
  run_ansible_play "Sync LDAP groups" ./playbooks/security/configure_ldap.yml
}

if [ "$0" != "$BASH_SOURCE" ]  ; then return; fi


### END COMMON SOURCED FUNCTIONS ###

usage() {
    cat <<EOF

      usage: ${SCRIPT_NAME} [command] [--source DIR]

      ================

      Commands are:

        * ${bold}stage${normal}		-	copy the media from the ISO
        * ${bold}properties${normal}	-	generate the properties file based on the installed version
        * ${bold}configure${normal}		-	setup the JumpHost 
        * ${bold}generate-config${normal}	-	generate config files


        * ${bold}push${normal}		-	push images to the JumpHost registry

        * ${bold}install${normal}	-	run the Ansible playbooks to install the cluster
            ${bold}--harden${normal}	-	Run the STIG remediation after installation
        * ${bold}harden${normal}	-	run the STIG remediation in the environment

        * ${bold}ping${normal}		-	ping all the Ansible hosts to test configuration
            ${bold}--loop${normal}	-	Loop ping command until its successful
        * ${bold}reboot${normal}	-	ping all the Ansible hosts to test configuration
        * ${bold}encrypt${normal}	-	encrypt the secret.yml and config.yml files
        * ${bold}decrypt${normal}	-	decrypt the secret.yml and config.yml files
        * ${bold}help${normal}		-	this help message

        * ${bold}setup${normal}   -     initial setup 


      Options:
        ${bold}--tail${normal}		-	tail output in realtime
        ${bold}--source DIR${normal}	-	the source directory of the ODIE media
        ${bold}--clean${normal}		-	Delete the ${OUTPUT_DIR} directory before installation
        ${bold}--stash${normal}		-	Stash and re-apply all working changes in the git repo
        ${bold}--nospin${normal}	-	Disable the spinning (set ${bold}SPIN_FPS${normal} for speed = ${SPIN_FPS}
        ${bold}--password${normal}		-	Prompt for the password of encrypted Vault config files


      Broken:
        * ${bold}validate${normal}	-	run the Ansible playbooks to validate the proper installation of the cluster
        * ${bold}patch${normal}		-	patch the cluster
      Deprecated Options:
        ${bold}--target BRANCH${normal}	-	The branch to checkout (current: ${TARGET})


EOF
}

export params="$(getopt -o dhs:t: -l tail,harden,target:,help,clean,stash,push,source:,nospin,password,loop --name ${SCRIPT_NAME} -- "$@")"

if [[ $? -ne 0 ]]
then
    usage
    exit 1
fi

eval set -- "$params"
#unset params

while true
do
    case $1 in
        -h|--help)
           usage
           shift
           exit 0
           ;;
        --harden)
          HARDEN_HOSTS=1
          shift
          ;;
        --clean)
          KEEP_CONTENT_DIR=0
          shift
          ;;
        --tail)
          SHOW_TAIL=1
          INTERACTIVE=0
          shift
          ;;
        --stash)
          STASH_UNCOMMITTED=1
          shift
          ;;
        --password)
          vault_password
          shift
          ;;
        --loop)
          LOOP_PING=1
          shift
          ;;
        --nospin)
          #OUTPUT_DIR=/mnt/sysimage/opt/odie
          INTERACTIVE=0
          shift
          ;;
        --source|-s)
          case "$2" in
            "") echo "${red}[ERROR]${normal}: Must specify a directory for ${bold}--source${normal}"; exit 1 ;;
            *) CONTENT_DIR="$2"; shift 2 ;;
          esac;
          ;;
        --target|-t)
          case "$2" in
            "") echo "${red}[ERROR]${normal}: Must specify a branch/tag for ${bold}--target${normal}"; exit 1 ;;
            *) TARGET="$2"; shift 2 ;;
          esac;
          ;;
        --skip-git)
          SKIP_GIT=1
          shift
          ;;

        --)
          shift; break ;;
        *)
          echo "Unknown arg: $1"
          exit 1
          ;;
    esac
done

function header() {

  COMMAND=${1:-""}
  MESSAGE=${2:-""}

  echo -n "${white}[${bold}ODIE v${INSTALLER_VERSION} |"
  echo -n "${green} OCP v${OCP_VERSION} ${white}| "
  echo -n "${yellow} LOG: ${LOG_FILE} ${white} |"
  echo -n "${blue} $COMMAND" 
  echo -n ${normal}
}


while true
do
  case $1 in
    stage)
      header
      stage
      shift
      exit 0
      ;;
    runonce)
	
      INTERACTIVE=0
      LOG_FILE=/root/odie-runonce.log
      header "Initial System Boot"
      setup
      shift
      exit 0
      ;;
    setup)
      header $1
      setup 
      shift
      exit 0
      ;;
    push|push-images)
      header
      push_images
      shift
      exit 0
      ;;
    properties|generate-properties)
      header
      setup_properties
      shift
      exit 0
      ;;
    generate-config)
      header
      echo
      generate_config
      exit 0
      ;;
    configure)
      header
      configure
      exit 0
      ;;
    harden)
      header
      harden_hosts
      exit 0
      ;;
    install)
      header
      install_cluster
      exit 0
      ;;
    patch)
      header
      patch_cluster
      exit 0
      ;;
    ping)
      header
      ping_hosts
      exit 0
      ;;
    reboot)
      header
      reboot_hosts
      exit 0
      ;;
    validate)
      header
      validate_hosts
      exit 0
      ;;
    help)
      usage
      shift
      exit 0
      ;;
    encrypt|decrypt)
      header
      set -e

      if [[ "${1}" == "encrypt" ]]; then
        TEXT="Encryption"
        cmd="encrypt"
        rm -rf /opt/odie/kickstart/* & spin $! "Removing existing kickstart files"
      else
        TEXT="Decryption"
        cmd="decrypt"
      fi

      print_message 0 "Config Files ${TEXT} :: Started"
      FILES=$(echo ${CONFIG_DIR}/secret.yml $(find ${PROJECTS_DIR} -name config.yml))
      ansible-vault ${cmd} ${FILES}

      complete_message "Config Files ${TEXT}"
      exit 0
      ;;
    auth)
      header
      case "$2" in
        install-htpasswd)
          cd ${GIT_CLONE}
          run_ansible_play "Install HTPasswd" ${MAKE_CMD} install_htpasswd
        ;;
        install-pivproxy) install_pivproxy;;
        update-pivproxy) update_pivproxy;;
        ldap-group-sync) ldap_group_sync;;
        ""|*) echo "${red}[ERROR]${normal}: Must specify ${bold}install-htpasswd${normal},${bold}install-pivproxy${normal},${bold}update-pivproxy${normal} or ${bold}ldap-group-sync${normal}"; exit 1 ;;
      esac;
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      usage
      shift
      exit 1
      ;;
  esac
done

usage
