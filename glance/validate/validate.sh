#!/bin/bash

IMAGE=cirros

case "$1" in
        control)
            # validate the control plane works before attempting dcn deploy
            FILES="control-planerc use-control-plane.sh"
            JUST_CONTROL=1
            ;;
         
        *)
            # validate dcn deploy works (cow boots on dcn) with multistore glance
            FILES="IMAGE control-planerc use-multistore-glance.sh use-central.sh use-dcn.sh"
            JUST_CONTROL=0
esac

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

for FILE in $FILES; do
    if [[ ! -e $FILE ]]; then
        echo "$FILE is missing. Aborting"
        exit 1
    else
        scp -q -o "StrictHostKeyChecking no" $FILE heat-admin@$CONTROLLER:/home/heat-admin/
    fi
done

if [[ $JUST_CONTROL -eq 1 ]]; then
    ssh -q -o "StrictHostKeyChecking no" heat-admin@$CONTROLLER "bash use-control-plane.sh"
else
    echo -e "Files transferred. To continue do the following:\n"
    echo "  ssh heat-admin@$CONTROLLER"
    echo "  bash use-multistore-glance.sh; bash use-central.sh; bash use-dcn.sh"
    echo ""
fi
