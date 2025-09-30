#!/bin/bash
loginctl enable-linger
podman container prune -y
podman system migrate
podman run --name vm-manager-container -p 3000:3000 -e DB_TWIG_URL='http://'`cat /etc/hostname`':8080/dbTwig' -d vm-manager
podman ps
