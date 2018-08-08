Kickstart Generator
===================

This role generates a kickstart file for each host based on the available host variables. It was developed specifically for use with creating OpenShift clusters on bare metal or in virtual environments where you don't have administrative access to the host systems. The included Kickstart template files are aimed towards creating master nodes, infrastructure nodes, application nodes, etc. for an OpenShift cluster install. The roles uses a host variable, 'flavor' to determine which template to use for each host.

Requirements
------------

A standard Ansible project directory with `host_vars` and `group_vars` directories works best for use with this role. Although any inventory structure and host variables method should work, this provides a means of easily tracking the variables for specific hosts, sets of hosts, and globally.

Role Variables
--------------

The following variables should be set for each host via host variables:
* hostname
* ip
* flavor (e.g. master, infra, node)

These variables can be read in individually by node or set with group variables:
* netmask
* dns
* env - This variable can be used to denote specific environments such as lab, dev, uat, sit, prod, etc.
* gateway

These variables are set in the role's defaults/main.yml file and should be overriden by setting them in the group_vars/all.yml file or elsewhere as appropriate:

* my_root_password - The unencrypted root password to be passed into the kickstart file (it will be encrypted)
* my_password_salt - Salt to be used for password encryption. Keep this below 10 characters.
* my_username - This non-root user will be created with administrative (wheel group) privileges
* my_password - The unencrypted password for your non-root user
* my_repo_host - IP address or hostname for the repository and image server
* my_timezone - Defaults to UTC
* my_ssh_key - The contents of an SSH keypair public file. Assign manually or use a lookup.

Dependencies
------------

This role is standalone and should not require any external dependencies.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: all
      gather_facts: no
      roles:
        - kickstart-generator

Example limited to a specific env:

    - hosts: lab
      gather_facts: no
      roles:
        - kickstart-generator

License
-------

BSD

Author Information
------------------

Stuart Bain <sbain@redhat.com>
