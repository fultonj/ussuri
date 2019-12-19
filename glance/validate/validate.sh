#!/bin/bash

source ~/stackrc

if [[ ! -e control-planerc ]]; then
    cp ../control-plane/control-planerc .
    if [[ ! -e control-planerc ]]; then
        echo "control-planerc is missing. abort."
        exit 1
    fi
fi

CONTROLLER=$(openstack server list -c Networks -c Name -f value | grep controller-0 | awk {'print $2'} | sed s/ctlplane=//g)

FILES="control-planerc use-multistore-glance.sh use-central.sh use-dcn.sh"
for FILE in $FILES; do
    if [[ ! -e $FILE ]]; then
        echo "$FILE is missing. Aborting"
        exit 1
    else
        scp -q -o "StrictHostKeyChecking no" $FILE heat-admin@$CONTROLLER:/home/heat-admin/
        if [[ $FILE != "control-planerc" ]]; then
            echo "Running $FILE ..."
            ssh -q -o "StrictHostKeyChecking no" heat-admin@$CONTROLLER "bash $FILE"
        fi
    fi
done
