#!/bin/bash
loginctl enable-linger
podman system migrate
podman container prune -f
podman run --name vm-manager-container --replace -p 3000:3000 -e DB_TWIG_URL='http://'`cat /etc/hostname`':8080/dbTwig' -d vm-manager
podman ps
