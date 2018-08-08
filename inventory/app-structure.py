#!/usr/bin/env python2.7
# App Structure Dynamic Inventory Script
# mbattles@redhat.com
# 08/14/17

# This script will parse the /opt/odie/projects directory structure and
# provide this information as facts into Ansible.

# It can be executed without parameters and will return a JSON structure
# The script assumes a default of /opt/odie/projects
# This can be modified by passing the ODIE_PARENT_PROJECT_PATH into the Ansible
# playbook

# Please refer to documentation/volumes/technical/app-conventions.adoc
# for more information about these conventions


import glob
import json
import yaml
import os
from StringIO import StringIO
from collections import defaultdict


parent_dir = os.getenv('ODIE_PARENT_PROJECT_PATH','/opt/odie/projects')
application_env = os.getenv('ODIE_SELECTED_APPLICATION')
project_env = os.getenv('ODIE_SELECTED_PROJECT')
password_file = os.getenv('ANSIBLE_VAULT_PASSWORD_FILE')

nested_dict = lambda: defaultdict(nested_dict)
root = nested_dict()

root['_meta']['hosts'] = []
root['all']['vars']['root_dir'] = parent_dir
root['all']['vars']['projects'] = []
all_dict = root['all']['vars']['projects'] = []

for project_fname in glob.glob(parent_dir + '/*'):
    project_name =  os.path.basename(project_fname)

    if project_env and project_name != project_env:
      continue

    project  = {}
    all_dict.append(project)

    project['name'] = project_name
    project['path'] = project_fname

    project['amq_build_path'] = project_fname + '/build/broker-amq'

    project['pvs'] = []
    for pv in glob.glob(project_fname+'/pvs/*'):
        pvs_name = os.path.basename(pv)
        project['pvs'].append(pvs_name);

    config_file = project_fname + "/config.yml"
    if os.path.isfile(config_file):

        if password_file:
            config = os.popen("ansible-vault view " + config_file + " --vault-password-file " + password_file)
        else:
            config = open(config_file, 'r')

        project['config'] = yaml.load(config)


    project['apps'] = []

    for app in glob.glob(project_fname+'/apps/*'):
        app_name = os.path.basename(app)
        if application_env and app_name != application_env:
          continue

        apps = {}
        project['apps'].append(apps)
        apps['name'] = app_name
        apps['path'] = app

        config_file = app + "/config.yml"
        if os.path.isfile(config_file):
            with open(config_file, 'r') as config:
                apps['config'] = yaml.load(config)

        apps['pvs'] = []
        for pv in glob.glob(app+'/pvs/*'):
            pvs_name = os.path.basename(pv)
            apps['pvs'].append(pvs_name);

        apps['builds'] = []
        for b in glob.glob(app+'/build/*'):
            build = {}
            build['name'] = os.path.basename(b)
            build['path'] = b
            apps['builds'].append(build);

        apps['images'] = []
        for i in glob.glob(app+'/images/*.yml'):

            if os.path.isfile(i):
                with open(i, 'r') as manifest:
                    apps['images'].append(yaml.load(manifest))

print json.dumps(root, indent=2)
