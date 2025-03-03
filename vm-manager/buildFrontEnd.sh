#!/bin/bash

set -e
# git pull
podman build . -f Dockerfile.multi -t vm-manager
set +e
rm vm-manager.tar
set -e
podman save -o vm-manager.tar localhost/vm-manager:latest
podman container prune --force
podman create --name vm-manager-container -p 3000:3000 -e AUTH_TRUST_HOST='true' -e DB_TWIG_URL='http://'`cat /etc/hostname`':8080/dbTwig' vm-manager
