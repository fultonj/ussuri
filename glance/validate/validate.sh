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
        if [[ $FILE != "control-planerc" && $FILE != "IMAGE" ]]; then
            echo "Running $FILE ..."
            ssh -q -o "StrictHostKeyChecking no" heat-admin@$CONTROLLER "bash $FILE"
            if [[ $? -gt 0 ]]; then
                echo "Aborting. Run of $FILE failed."
                exit 1
            fi
        fi
    fi
done

echo "Echo checking Ceph on $DCN_NAME"
DCN=$(openstack server list -c Networks -c Name -f value | grep $DCN_NAME | awk {'print $2'} | sed s/ctlplane=//g)
CMD0="sudo podman exec ceph-mon-\$(hostname) rbd -p images ls -l --cluster $DCN_NAME"
CMD1="sudo podman exec ceph-mon-\$(hostname) rbd -p vms ls -l --cluster $DCN_NAME"
ssh -q -o "StrictHostKeyChecking no" heat-admin@$DCN "$CMD0; $CMD1"
