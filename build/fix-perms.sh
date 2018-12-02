#!/bin/bash
set -e

user=$(id -un):$(id -gn);
sudo chown -R $user /opt/odie/src
sudo chown -R $user /opt/odie/config
sudo chown -R $user /etc/odie-release

sudo find /opt/odie/src/output -exec chmod +w {} \;

