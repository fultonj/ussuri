#!/usr/bin/env bash
# Create a "pet" VM on $AZ by cloning an volume from
# an image and then booting that image.

AZ="dcn0"
IMAGE=cirros
CLEAN=1
CINDER=0
NOVA=1

VOLUME_NAME="pet-volume-${AZ}"
SERVER_NAME="pet-server-${AZ}"
RC=../control-plane/control-planerc
if [[ ! -e $RC ]]; then
    echo "$RC is missing. Aborting."
    exit 1
fi
source $RC

IMG_ID=$(openstack image show $IMAGE -c id -f value)
if [[ $? != 0 ]]; then
    echo "Unable to find Glance image: $IMAGE . Aborting."
    exit 1
fi

PRI_NET_ID=$(openstack network show private-${AZ} -c id -f value)
if [[ -z $PRI_NET_ID ]]; then
    echo "Prerequisite failure: use-dcn.sh does not seem to have been run for $AZ yet"
    exit 1
fi

if [[ $CLEAN -eq 1 ]]; then
    echo "Deleting previous Nova server(s)"
    for ID in $(openstack server list -f value -c ID); do
        openstack server delete $ID;
    done

    echo "Deleting previous Cinder volume(s)"
    for ID in $(openstack volume list -f value -c ID); do
        openstack volume delete $ID;
    done
fi

if [[ $CINDER -eq 1 ]]; then
    echo "Creating Cinder volume $VOLUME_NAME from $IMG_ID"
    openstack volume create --size 8 --availability-zone $AZ $VOLUME_NAME --image $IMG_ID
    VOL_ID=$(openstack volume show -f value -c id $VOLUME_NAME)
    if [[ $? != 0 ]]; then
        echo "Unable to find volume: $VOLUME_NAME. Aborting."
        exit 1
    fi
fi


if [[ $NOVA -eq 1 ]]; then
    echo "Creating Nova server $SERVER_NAME from $VOL_ID"
    if [[ $CINDER -eq 1 ]]; then
        openstack server create --flavor tiny --key-name demokp-${AZ} --network private-${AZ} --security-group basic --availability-zone $AZ --volume $VOL_ID $SERVER_NAME
    else
        # have nova ask cinder to create the volume
        openstack server create --flavor tiny --image $IMG_ID --key-name demokp-${AZ} --network private-${AZ} --security-group basic --availability-zone $AZ --boot-from-volume 4 $SERVER_NAME
    fi

    STATUS=$(openstack server show $SERVER_NAME -f value -c status)
    echo "Server status: $STATUS (waiting)"
    while [[ $STATUS == "BUILD" ]]; do
        sleep 1
        echo -n "."
        STATUS=$(openstack server show $SERVER_NAME -f value -c status)
    done
    echo ""
    if [[ $STATUS == "ERROR" ]]; then
        echo "Server build failed; aborting."
        openstack server list
        exit 1
    fi
    if [[ $STATUS == "ACTIVE" ]]; then
        openstack server list
    fi
fi
