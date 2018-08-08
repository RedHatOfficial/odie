#!/usr/bin/env python2.7
#
# This script will convert the hosts.csv file into host variables
# files using the 'hostname' column as the filename.
# Environment Variables:
#   - ODIE_HOST_CSV = The path to the `hosts.csv` file (defaults to `/opt/odie/config/hosts.csv`)
#
#
import csv
import yaml
import sys
import os
import json
from collections import defaultdict

host_file = os.getenv('ODIE_HOST_CSV','/opt/odie/config/hosts.csv')

if os.path.isfile(host_file):
    my_csv_file = host_file
else:
    print json.dumps({}, indent=2)
    sys.exit(0)

csv_file = open(my_csv_file)
rd = csv.DictReader(row for row in csv_file if not row.startswith('#'))

nested_dict = lambda: defaultdict(nested_dict)
root = nested_dict()
root['all'] = {}
root['all']['hosts'] = []

root['masters']['hosts'] = []
root['etcd']['hosts'] = []
root['infra']['hosts'] = []
root['nodes']['hosts'] = []
root['lb_nfs']['hosts'] = []
root['nfs']['hosts'] = []
root['lb']['hosts'] = []
root['registry']['hosts'] = []
root['media']['hosts'] = []
root['jumphost']['hosts'] = []
root['glusterfs']['hosts'] = []

root['_meta'] = {}
root['_meta']['hostvars'] = {}
root['_meta']['hosts'] = []

for host_data in rd:
    host_vars = 'host_vars/' + host_data['hostname'] + '.yml'
    hostname = host_data['hostname']

    # Legacy: Zone was introduced in 0.3.2, this is for backwards compat
    if not 'zone' in host_data:
      host_data['zone'] = host_data['env']


    # remove undefined variables so we will use the defaults
    orig_data = host_data.copy()
    for key in orig_data:
      if orig_data[key] == '':
        host_data.pop(key)
      if orig_data[key].isdigit():
        host_data[key] = int(host_data[key])

    root['all']['hosts'].append(host_data['hostname'])
    # Build our OCP installer groups here
    if host_data['flavor'] == 'master':
        root['masters']['hosts'].append(host_data['hostname'])
        root['etcd']['hosts'].append(host_data['hostname'])

    if host_data['flavor'] == 'infra':
        root['infra']['hosts'].append(host_data['hostname'])

    if host_data['flavor'] == 'node':
        root['nodes']['hosts'].append(host_data['hostname'])

    if host_data['flavor'] == 'lb_nfs':
        root['lb_nfs']['hosts'].append(host_data['hostname'])
        root['nfs']['hosts'].append(host_data['hostname'])
        root['lb']['hosts'].append(host_data['hostname'])

    if host_data['flavor'] == 'registry':
        root['registry']['hosts'].append(host_data['hostname'])

    if host_data['flavor'] == 'media':
        root['media']['hosts'].append(host_data['hostname'])

    if host_data['flavor'] == 'jumphost':
        root['jumphost']['hosts'].append(host_data['hostname'])

    if 'cns' in host_data:
        root['glusterfs']['hosts'].append(host_data['hostname'])

    root['_meta']['hostvars'][hostname] = host_data

print json.dumps(root, indent=2)
