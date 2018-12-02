#!/bin/bash
set -e

user=$(id -un):$(id -gn);
sudo chown --dereference -H -R $user /opt/odie/src
sudo chown --dereference -H -R $user /opt/odie/config
sudo chown --dereference -H -R $user /opt/odie/src/output
sudo chown  $user /etc/odie-release

sudo find /opt/odie/src/output -exec chmod +w {} \;

