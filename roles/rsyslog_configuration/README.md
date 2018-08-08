Role Name
=========

This role sets up rsyslog export to an external host when given the host, port, and protocol to export to.

Requirements
------------

This role requires that the rsyslog package be installed.

Role Variables
--------------

The four variables needed for this role are:

- setup_rsyslog_export
 - Default: *false*
 - This should be set to *true* via a group or host var to enable the role
- rsyslog_export_host 
 - Default: none
 - This needs to be set via group or host vars to the hostname of the rsyslog server to export logs to
- rsyslog_export_protocol
 - Default: udp
 - This only needs to be set via group or host var if the protocol is tcp
- rsyslog_export_port
 - Default: 514
 - This only needs to be set if the default 514 syslog port is not being used
- rsyslog_var_log_size
 - Default: 52428800
 - The size of each `/var/log/messages` file (5 of these will be kept)
-  setup_remote_rsyslog_export
 - Default: True
 - Whether the rsyslog server should be configured on the lbnfs node
- remote_rsyslog_export_hostname
 - what server should be used as the target rsyslog server (unused)
 

Dependencies
------------

This role does not depend on any other roles.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - name: Play to set up rsyslog
      hosts: servers
      vars:
        setup_rsyslog_export: true
        rsyslog_export_host: loghost.example.com
        rsyslog_export_protocol: udp
        rsyslog_export_port: 514
      roles:
         - rsyslog_configuration

License
-------

BSD

Author Information
------------------

Stuart Bain sbain@redhat.com
Stephen Palmer spalmer@redhat.com
Mike Battles mbattles@redhat.com
