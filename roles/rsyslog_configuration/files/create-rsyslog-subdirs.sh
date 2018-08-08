#! /bin/sh
# set -x

/usr/bin/rm -f /opt/odie/src/contrib/scripts/hosts-file.txt
/usr/bin/rm -f /opt/odie/src/contrib/scripts/list-hosts.txt

/usr/bin/gawk -F[,] '$1 !~ /hostname/ {print $1}' /opt/odie/src/inventory/hosts.csv >> /opt/odie/src/contrib/scripts/list-hosts.txt

echo "
## Create subdirectories under /var/log/hosts for each node in the cluster
## The line with the tilde means don't leave any logs from source host in /var/log/messages" >> /opt/odie/src/contrib/scripts/hosts-file.txt

for HOST in $(< /opt/odie/src/contrib/scripts/list-hosts.txt)
do

echo :fromhost, isequal, \"${HOST}\" /var/log/hosts/${HOST}/messages >> /opt/odie/src/contrib/scripts/hosts-file.txt
echo :fromhost, isequal, \"${HOST}\" \~ >> /opt/odie/src/contrib/scripts/hosts-file.txt

done

if [[ ! -f /opt/odie/src/contrib/scripts/rsyslog.conf-remote-template.orig ]]
then
/usr/bin/cp /opt/odie/src/contrib/scripts/rsyslog.conf-remote-template /opt/odie/src/contrib/scripts/rsyslog.conf-remote-template.orig
fi

/usr/bin/cp /opt/odie/src/contrib/scripts/rsyslog.conf-remote-template.orig /opt/odie/src/contrib/scripts/rsyslog.conf-remote-template

/usr/bin/sed -i '/$IMJournalStateFile imjournal.state/r /opt/odie/src/contrib/scripts/hosts-file.txt' /opt/odie/src/contrib/scripts/rsyslog.conf-remote-template

exit 0

