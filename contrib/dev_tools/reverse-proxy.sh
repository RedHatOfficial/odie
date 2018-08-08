#!/usr/bin/env bash
#reverse proxy setting for the lab environment
nohup socat tcp-listen:8443,reuseaddr,fork tcp:10.15.74.110:8443 &
nohup socat tcp-listen:443,reuseaddr,fork tcp:10.15.74.104:443 &
nohup socat tcp-listen:389,reuseaddr,fork tcp:10.15.75.71:389 &
nohup socat tcp-listen:636,reuseaddr,fork tcp:10.15.75.71:636 &
