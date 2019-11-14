#!/bin/bash

source ~/stackrc
CONTROLLER=$(openstack server list -c Networks -c Name -f value | grep controller-0 | awk {'print $2'} | sed s/ctlplane=//g)

FILES="overcloudrc use-overcloud.sh"
for FILE in $FILES; do
    if [[ ! -e $FILE ]]; then
        echo "$FILE is missing. Aborting"
        exit 1
    else
        scp $FILE heat-admin@$CONTROLLER:/home/heat-admin/
    fi
done
ssh heat-admin@$CONTROLLER "bash use-overcloud.sh"
