#!/bin/bash

osinfo-query os --fields=short-id,name >osVariantList.txt
sed -f prepOsVariantList.sed osVariantList.txt | tr -s " " | sed "s/ ')/')/" | sed "1s/^/whenever sqlerror exit\n/" >osVariantList.sql
rm osVariantList.txt
