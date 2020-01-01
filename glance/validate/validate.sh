#!/bin/bash

IMAGE=cirros
DCN_NAME=dcn0

source ~/stackrc

if [[ ! -e control-planerc ]]; then
    cp ../control-plane/control-planerc .
    if [[ ! -e control-planerc ]]; then
        echo "control-planerc is missing. abort."
        exit 1
    fi
fi

echo $IMAGE > IMAGE
CONTROLLER=$(openstack server list -c Networks -c Name -f value | grep controller-0 | awk {'print $2'} | sed s/ctlplane=//g)

FILES="IMAGE control-planerc use-multistore-glance.sh use-central.sh use-dcn.sh"
for FILE in $FILES; do
    if [[ ! -e $FILE ]]; then
        echo "$FILE is missing. Aborting"
        exit 1
    else
        scp -q -o "StrictHostKeyChecking no" $FILE heat-admin@$CONTROLLER:/home/heat-admin/
    fi
done

echo -e "Files transferred. To continue do the following:\n"
echo "  ssh heat-admin@$CONTROLLER"
echo "  bash use-multistore-glance.sh; bash use-central.sh; bash use-dcn.sh"
echo ""
