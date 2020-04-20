#!/usr/bin/env bash
# -------------------------------------------------------
# Use the following setting VARIABLE test each scenario
# I.   DCN A/A Volume Snapshots?
SNAP_TO_VOLUME=1
# II.  DCN Instance Snapshots to Images?
SNAP_TO_IMAGE=0
# III.  DCN Instance (booted from volume) Snapshots to Volumes?
SNAP_PET_TO_VOLUME=0
# IV. Push image created from instance snapshot (II) back to central?
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
if [[ $SNAP_TO_IMAGE -eq 1 ]]; then
    echo "Testing SNAP_TO_IMAGE"
fi
# -------------------------------------------------------
if [[ $SNAP_PET_TO_VOLUME -eq 1 ]]; then
    echo "Testing SNAP_PET_TO_VOLUME"
fi
# -------------------------------------------------------
if [[ $PUSH -eq 1 ]]; then
    echo "Testing PUSH of image created from SNAP_TO_IMAGE"
fi
# -------------------------------------------------------
