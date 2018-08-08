#!/bin/bash
set -e

REPO_XML=/opt/odie/repo/odie-custom/repodata/repomd.xml
GPG_BASEDIR=/root/.gnupg
GPG_CONF=${GPG_BASEDIR}/generate_script
GPG_PUBLIC_PATH=${GPG_BASEDIR}/gpg_key.pub
GPG_SECRET_PATH=${GPG_BASEDIR}/gpg_key.sec
EXISTING_GPG_PUBLIC_PATH=/opt/odie/config/repo_gpg_key.pub
EXISTING_GPG_SECRET_PATH=/opt/odie/config/repo_gpg_key.sec
#KEY_PAIR_NAME=odie-jumphost
KEY_PAIR_NAME=odie-build-server
PUBLIC_KEY_PATH=/etc/pki/rpm-gpg/RPM-GPG-KEY-$KEY_PAIR_NAME

# Ensure proper directory structure exists and remove existing signed repomd.xml file
mkdir -p ${GPG_BASEDIR}
touch ${GPG_BASEDIR}/gpg.conf
chmod -R 0700 ${GPG_BASEDIR}
echo "use-agent" > ${GPG_BASEDIR}/gpg.conf
rm -rf $REPO_XML.asc

# If a user-provided key pair exists, those will be used instead of auto-generated keys
if [[ -f $EXISTING_GPG_PUBLIC_PATH && -f $EXISTING_GPG_SECRET_PATH ]]
then
  echo "Using existing GPG keys"
  cp $EXISTING_GPG_PUBLIC_PATH $GPG_PUBLIC_PATH
  cp $EXISTING_GPG_SECRET_PATH $GPG_SECRET_PATH
elif [[ ! -f $GPG_PUBLIC_PATH && ! -f $GPG_SECRET_PATH ]] # Automate key generation if no keys exist
then
  echo "Generating new GPG keys"
  cat > ${GPG_CONF} << EOF
    #
    # Ref https://www.gnupg.org/documentation/manuals/gnupg-2.0/Unattended-GPG-key-generation.html
    #
    %echo Generating a basic OpenPGP key
    Key-Type: 1
    Key-Length: 2048
    Name-Real: $KEY_PAIR_NAME
    Name-Email: $KEY_PAIR_NAME@redhat.com
    Expire-Date: 0
    %pubring $GPG_PUBLIC_PATH
    %secring $GPG_SECRET_PATH
    %commit
    %echo done
# Following line unindented to prevent syntax highlighting weirdness in vim
EOF
  gpg2 --batch --gen-key ${GPG_CONF}
fi

# Ensure idempotency by removing existing keys from gpg database
EXISTING_PRIVATE_KEY=$(gpg2 --list-secret-keys --with-colons --fingerprint $KEY_PAIR_NAME | grep "^fpr" | cut -d: -f10)
EXISTING_PUBLIC_KEY=$(gpg2 --list-keys --with-colons --fingerprint $KEY_PAIR_NAME | grep "^fpr" | cut -d: -f10)

if [ ! -z $EXISTING_PRIVATE_KEY ]
then
  gpg2 --batch --delete-secret-key $EXISTING_PRIVATE_KEY
fi

if [ ! -z $EXISTING_PUBLIC_KEY ]
then
  gpg2 --batch --delete-key $EXISTING_PUBLIC_KEY
fi

# Generate and import public/private key
gpg2 --import $GPG_PUBLIC_PATH
gpg2 --import $GPG_SECRET_PATH

# Export keypair ID for reference by "rpm" command
KEY_ID=$(gpg2 --list-public-keys $KEY_PAIR_NAME | grep "pub" | cut -d '/' -f2 | cut -d ' ' -f1)
echo "%_gpg_name $KEY_ID" > /root/.rpmmacros

# Export public key, change selinux context and import into RPM database
gpg2 --export -a $KEY_ID > $PUBLIC_KEY_PATH
chcon system_u:object_r:cert_t:s0 $PUBLIC_KEY_PATH
rpm --import $PUBLIC_KEY_PATH

# Sign repository
echo $PASSPHRASE | gpg2 --batch --default-key $KEY_ID --passphrase-fd 0 --armor --detach-sign $REPO_XML
echo "Signed repository at $REPO_XML"

## WIP for enabling SSL on apache
## Create certificate for HTTPS in default locations expected by Apache
#openssl req -x509 -nodes -days 1825 -newkey rsa:2048 -keyout /etc/pki/tls/private/localhost.key -out /etc/pki/tls/certs/localhost.crt
#
## Allow HTTPS traffic through firewall
#firewall-cmd --permanent --add-port=443/tcp
#firewall-cmd --reload
#
## Reload httpd daemon
#systemctl restart httpd
