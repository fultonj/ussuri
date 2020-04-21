#!/usr/bin/env bash
# -------------------------------------------------------
# Use the following setting VARIABLE test each scenario
# I.   DCN A/A Volume Snapshots?
SNAP_TO_VOLUME=0
# II.  DCN Instance (booted from volume) Snapshots to Volumes?
SNAP_PET_TO_VOLUME=1
# III.  DCN Instance Snapshots to Images?
SNAP_TO_IMAGE=0
# IV. Push image created from instance snapshot (III) back to central?
PUSH=0
# -------------------------------------------------------
AZ="dcn0"
IMAGE=cirros
RC=../control-plane/control-planerc
if [[ ! -e $RC ]]; then
    echo "$RC is missing. Aborting."
    exit 1
fi
source $RC
# -------------------------------------------------------
if [[ $SNAP_TO_VOLUME -eq 1 ]]; then
    echo "Testing SNAP_TO_VOLUME"
    BASE=make_snap_from_${AZ}
    SNAP=snap_${AZ}
    # deleting old snapshots and volumes from previous any runs of this test
    for ID in $(openstack volume snapshot list -f value -c ID -c Name  | grep snap | awk {'print $1'}); do
        openstack volume snapshot delete $ID;
    done
    for ID in $(openstack volume list -f value -c ID -c Name  | grep snap | awk {'print $1'}); do
        openstack volume delete $ID;
    done
    echo "Creating Cinder volume: $BASE"
    openstack volume create --size 1 --availability-zone $AZ $BASE
    if [ $? != "0" ]; then
        echo "Error creating a volume in AZ ${AZ}."
        exit 1
    fi
    for i in {1..5}; do
        sleep 1
        STATUS=$(openstack volume show $BASE -f value -c status)
        if [[ $STATUS == "available" || $STATUS == "error" ]]; then
	    break
        fi
    done
    if [[ $STATUS != "available" ]]; then
        echo "Volume create for $BASE failed; aborting."
        exit 1
    fi
    openstack volume snapshot create $SNAP --volume $BASE
    openstack volume list
    openstack volume snapshot list
fi
# -------------------------------------------------------
if [[ $SNAP_PET_TO_VOLUME -eq 1 ]]; then
    echo "Testing SNAP_PET_TO_VOLUME"
    BASE=pet-server-$AZ
    SNAP=pet-server-$AZ-snapshot
    NOVA_ID=$(openstack server show $BASE -f value -c id)
    if [[ ! $(echo $NOVA_ID | grep -E "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}" | wc -l) -eq 1 ]]; then
        echo "Unable to find $BASE. Please run dcn-pet.sh"
        exit 1
    fi
    CINDER_ID=$(openstack volume list -f value -c ID -c "Attached to" | grep $NOVA_ID | awk {'print $1'} | head -1)
    echo "Found server: $NOVA_ID"
    echo "Found volume: $CINDER_ID"
    echo "Stopping server (cannot shapshot while volume is in-use)"
    openstack server stop $NOVA_ID
    i=0
    STATUS=$(openstack server show $NOVA_ID  -f value -c status)
    echo -n "Waiting for server to stop"
    while [[ $STATUS == "ACTIVE" ]]; do
        echo -n "."
        sleep 1
        i=$(($i+1))
        if [[ $i -gt 30 ]]; then break; fi
        STATUS=$(openstack server show $NOVA_ID  -f value -c status)
    done
    echo "."
    if [[ $STATUS != "SHUTOFF" ]]; then
        echo "Server is not cleanly SHUTOFF. Exiting."
        exit 1
    fi
    i=0
    echo "Detaching volume (cannot snapshot a volume that is in-use)"
    openstack server remove volume $NOVA_ID $CINDER_ID
    STATUS=$(openstack volume show $CINDER_ID  -f value -c status)
    while [[ $STATUS == "in-use" ]]; do
        echo -n "."
        sleep 1
        i=$(($i+1))
        if [[ $i -gt 3 ]]; then break; fi
        STATUS=$(openstack volume show $CINDER_ID  -f value -c status)
    done
    echo "."
    if [[ $STATUS != "available" ]]; then
        echo -e "Unable to create snapshot: cinder volume is not available."
    else
        echo "Creating snapshot $SNAP"
        openstack volume snapshot create $SNAP --volume $CINDER_ID
    fi
    echo "Re-attaching volume and starting server"
    openstack server add volume $NOVA_ID $CINDER_ID
    openstack server start $NOVA_ID
    openstack server list
    openstack volume list
    openstack volume snapshot list
fi
# -------------------------------------------------------
if [[ $SNAP_TO_IMAGE -eq 1 ]]; then
    echo "Testing SNAP_TO_IMAGE"
fi
# -------------------------------------------------------
if [[ $PUSH -eq 1 ]]; then
    echo "Testing PUSH of image created from SNAP_TO_IMAGE"
fi
# -------------------------------------------------------
