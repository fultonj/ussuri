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
    echo "Listing contents of ceph volumes pools"
    bash ls_rbd.sh volumes
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
    echo "Listing contents of ceph volumes pools"
    bash ls_rbd.sh volumes
fi
# -------------------------------------------------------
if [[ $SNAP_PET_TO_VOLUME -eq 1 ]]; then
    echo "Testing SNAP_PET_TO_VOLUME"
    BASE=pet-server-$AZ
    SNAP=pet-server-$AZ-snapshot-$(date "+%Y_%m_%d_%T")
    NOVA_ID=$(openstack server show $BASE -f value -c id)
    if [[ ! $(echo $NOVA_ID | grep -E "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}" | wc -l) -eq 1 ]]; then
        echo "Unable to find $BASE. Please run dcn-pet.sh"
        exit 1
    fi
    CINDER_ID=$(openstack volume list -f value -c ID -c "Attached to" | grep $NOVA_ID | awk {'print $1'} | head -1)
    echo "Found server: $NOVA_ID"
    echo "Found volume: $CINDER_ID"
    echo "Stopping server to quiesce data for clean snapshot"
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
    echo "Creating snapshot $SNAP"
    openstack volume snapshot create $SNAP --volume $CINDER_ID --force
    openstack volume list
    openstack volume snapshot list
    echo "Starting server"
    openstack server start $NOVA_ID
    openstack server list
fi
# -------------------------------------------------------
if [[ $SNAP_TO_IMAGE -eq 1 ]]; then
    # https://docs.openstack.org/nova/rocky/admin/migrate-instance-with-snapshot.html
    echo "Testing SNAP_TO_IMAGE"
    BASE=myserver-$AZ
    SNAP=myserver-$AZ-snapshot
    NOVA_ID=$(openstack server show $BASE -f value -c id)
    if [[ ! $(echo $NOVA_ID | grep -E "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}" | wc -l) -eq 1 ]]; then
        echo "Unable to find $BASE. Please run use-dcn.sh"
        exit 1
    fi
    echo "Found $BASE with UUID $NOVA_ID"
    IMAGE_ID=$(openstack image show $SNAP -f value -c id)
    if [[ $(echo $IMAGE_ID | grep -E "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}" | wc -l) -eq 1 ]]; then
        echo "Found $SNAP with UUID $IMAGE_ID to be replaced. Deleting."
        openstack image delete $IMAGE_ID
    fi
    echo "Stopping server (to ensure data is flushed to disk for clean snapshot)"
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
    echo "Listing contents of ceph glance pools"
    bash ls_rbd.sh images
    echo "Creating Glance image $SNAP"
    openstack server image create --name $SNAP $NOVA_ID
    openstack image list
    STATUS=$(openstack image show $SNAP -f value -c status)
    echo -n "Waiting for instance to be ready to boot again"
    while [[ $STATUS == "queued" ]]; do
        echo -n "."
        sleep 1
        i=$(($i+1))
        if [[ $i -gt 30 ]]; then break; fi
        STATUS=$(openstack image show $SNAP -f value -c status)
    done
    echo "."
    if [[ $STATUS != "active" ]]; then
        echo "Snapshot of image did not become active."
    else
        echo "Snapshot should now be complete"
        openstack image list
        echo "Listing contents of ceph glance pools"
        bash ls_rbd.sh images
    fi
    echo "Starting server"
    openstack server start $NOVA_ID
    echo -n ".."
    sleep 2
    echo "."
    openstack server list
fi
# -------------------------------------------------------
if [[ $PUSH -eq 1 ]]; then
    echo "Testing PUSH of image created from SNAP_TO_IMAGE"
    SNAP=myserver-$AZ-snapshot
    IMAGE_ID=$(openstack image show $SNAP -f value -c id)
    if [[ ! $(echo $IMAGE_ID | grep -E "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}" | wc -l) -eq 1 ]]; then
        echo "Unable to Find $SNAP Glance image"
        openstack image list
        echo "Rerun with SNAP_TO_IMAGE=1"
        echo "Exiting"
        exit 1
    fi
    echo "Found $SNAP with UUID $IMAGE_ID"
    echo "Available stores:"
    glance stores-info
    STORES=$(openstack image show $IMAGE_ID -f value -c properties | sed -e s/\'/\"/g -e s/False/0/g -e s/True/1/g | jq .stores)
    echo "$SNAP is in stores: $STORES"
    #openstack image show $IMAGE_ID | egrep "properties"
    echo "Listing contents of ceph glance pools"
    bash ls_rbd.sh images

    echo "Requesting glance copy the image to the default_backend at the central ceph"
    glance image-import $IMAGE_ID --stores default_backend --import-method copy-image
    echo -n "Waiting for image to be copied..."
    while [[ $(echo $STORES | grep default | wc -l) -eq 0 ]]; do
        echo -n "."
        sleep 1
        i=$(($i+1))
        if [[ $i -gt 30 ]]; then break; fi
        STORES=$(openstack image show $IMAGE_ID -f value -c properties | sed -e s/\'/\"/g -e s/False/0/g -e s/True/1/g | jq .stores)
    done
    echo "."
    echo "Stores for $SNAP is $STORES"
    if [[ $STORES != "\"$AZ,default_backend\"" ]]; then
        echo "Result of stores after copy is not as expected. Exiting."
        exit 1
    fi
    echo ""
    openstack image show $IMAGE_ID | egrep "properties|stores"
    echo ""
    echo "Listing contents of ceph glance pools"
    bash ls_rbd.sh images
    echo "To boot $SNAP on the central site as a new instance "
    echo "run use-central.sh with IMAGE=$SNAP"
    echo ""
    echo "To boot $SNAP on central as a pet run dcn-pet.sh but"
    echo "uncomment variables under 'Pets from the edge'"
fi
