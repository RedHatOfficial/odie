#!/usr/bin/bash
#
# This script will rotate the logs in /var/log/messages and keep 5 copies of each
# The size of each log is defined in /etc/rsyslog.conf on the system
# ODIE will configure this value via the rsyslog_configuration role using the
#       var_log_messages_size ansible variable

LOG_FILE=/var/log/messages

for i in `seq 0 5| sort -r` ; do if [[ -f "$LOG_FILE.$i" ]] ; then mv -f $LOG_FILE.$i $LOG_FILE.$(( $i + 1 )) ; fi;  done;
rm -f $LOG_FILE.6
mv ${LOG_FILE} ${LOG_FILE}.0
