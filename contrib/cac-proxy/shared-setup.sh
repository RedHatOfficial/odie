#!/bin/bash

# set permissions
chgrp -R 0 /apache
chmod u+x,g+x /apache/start.sh
chgrp -R 0 /run/httpd
chgrp -R 0 /etc/httpd
chmod -R g+wx /run/httpd
chmod -R g+wx /etc/httpd/conf.d
chmod -R g+wx /etc/httpd/run
chmod -R g+wx /etc/httpd/logs
chmod -R g+rwx /var/log/httpd

# remove unused apache files
rm -f /etc/httpd/conf.d/ssl.conf
rm -f /etc/httpd/conf.d/autoindex.conf
rm -f /etc/httpd/conf.d/userdir.conf
rm -f /etc/httpd/conf.d/README
rm -f /etc/httpd/conf.d/welcome.conf

# remove unused module configurations
rm -f /etc/httpd/conf.modules.d/00-dav.conf
rm -f /etc/httpd/conf.modules.d/00-lua.conf
rm -f /etc/httpd/conf.modules.d/00-cgi.conf

# change apache ports as needed
sed -i 's/Listen 80/Listen 8080/g' /etc/httpd/conf/httpd.conf

#######################################################################################
# STIG Checklist Items
#######################################################################################

# High - V-2258
# set permissions on cgi-bin
chmod u-w,g-rwx,o-rwx /var/www/cgi-bin
chgrp 0 /var/www/cgi-bin

# High - V-2227
# change index option and remove symlink following
sed -i 's/Options Indexes FollowSymLinks/Options -Indexes +SymLinksIfOwnerMatch/g' /etc/httpd/conf/httpd.conf

# Medium - V-13688
# Medium - V-26280
# set log format to standard from STIG
sed -i 's/LogFormat.+combined$/LogFormat \"%a %A %h %H %l %m %s %t %u %U \"%{Referer}i\"\" combined/g' /etc/httpd/conf/httpd.conf
