#!/bin/bash
# By default this uploads the image to "stores": ["central", "dcn0"]
# Modify the curl request below accordingly to add other stores.
# 
# Don't use a real cirros image, just use a small file
SMALL=0
# Run same RBD commands against cinder to compare results
CINDER=0
# -------------------------------------------------------
if [[ -e control-planerc ]]; then
    source control-planerc
else
    echo "control-planerc is missing. abort."
    exit 1
fi

case "$1" in
        import)
            PATCH=import-multi-stores
            ;;
         
        copy)
            PATCH=copy-existing-image
            ;;
         
        *)
            echo "Usage: $0 {copy|import}"
            exit 1
esac

echo "Testing feature $PATCH on $STORES"
# -------------------------------------------------------
# get image
NAME=cirros-0.3.4
IMG=cirros-0.3.4-x86_64-disk.img
RAW=$(echo $IMG | sed s/img/raw/g)
URL=http://download.cirros-cloud.net/0.3.4/$IMG
if [ ! -f $RAW ]; then
    if [ ! -f $IMG ]; then
        echo "Could not find qemu image $img; downloading a copy."
        curl -# $URL > $IMG
    fi
    echo "Could not find raw image $raw; converting."
    qemu-img convert -f qcow2 -O raw $IMG $RAW
fi
# -------------------------------------------------------
if [ $SMALL -eq 1 ]; then
    NAME=myfile
    RAW=/tmp/$NAME
    if [[ ! -e $RAW ]]; then
        echo $NAME > $RAW
    fi
    echo "Using a small file to test with: $RAW"
fi
# -------------------------------------------------------
OLD_ID=$(openstack image show $NAME -f value -c id)
if [[ ! -z $OLD_ID ]]; then 
    echo "- Clean out old image"
    openstack image delete $OLD_ID
fi
# -------------------------------------------------------
echo "- List available stores"
glance stores-info

echo "- Create image"
glance --verbose image-create-via-import --disk-format raw --container-format bare --name $NAME
ID=$(openstack image show $NAME -c id -f value)

echo "- Upload image data to staging"
glance --verbose image-stage $ID --file $RAW

echo "- Get token"
TOKEN=$(openstack token issue -f value -c id)

echo "- Get glance endpoint"
ENDPOINT=$(openstack endpoint list -c "Service Name" -c "Interface" -c "URL" \
                     -f value | grep glance | grep public | awk {'print $3'})

if [[ $PATCH == "import-multi-stores" ]]; then
    echo "- Import $NAME into multiple stores with curl"
    set -o xtrace
    curl -g -i -X POST $ENDPOINT/v2/images/$ID/import -H "User-Agent: python-glanceclient" -H "Content-Type: application/json" -H "X-Auth-Token: $TOKEN" -d '{"method": {"name": "glance-direct"}, "stores": ["central", "dcn0"]}'
    set +o xtrace
fi

if [[ $PATCH == "copy-existing-image" ]]; then
    echo "- Copy $NAME between multiple stores $STORES with curl"
    set -o xtrace
    curl -g -i -X POST $ENDPOINT/v2/images/$ID/import -H "User-Agent: python-glanceclient" -H "Content-Type: application/json" -H "X-Auth-Token: $TOKEN" -d '{"method": {"name": "copy-image"}, "stores": ["central", "dcn0"]}'
    set +o xtrace
fi

openstack image show $NAME

echo "Looking at glance tasks"
glance task-list | head -5

echo "Show newest task"
TASK_ID=$(glance task-list | head -4 | grep processing | awk {'print $2'})
glance task-show $TASK_ID
echo "Confirm image ID in task"
glance task-show $TASK_ID | grep $ID

echo "Waiting for image to finish uploading or importing..."
i=0
while [ 1 ]; do
    STATUS=$(openstack image show $NAME -f value -c status)
    if [[ $STATUS == "importing" || $STATUS == "uploading" ]]; then
        echo -n "."
        sleep 5
        i=$(($i+1))
    else
        break;
    fi
    if [[ $i -gt 20 ]]; then
        echo "Giving up after $(($i * 5)) seconds"
        exit 1
    fi
done

echo "- Use RBD to list images on central"
sudo podman exec ceph-mon-$(hostname) rbd -p images ls -l

echo "- Use RBD to list images on dcn0"
sudo podman exec ceph-mon-$(hostname) rbd --id dcn0.glance --keyring /etc/ceph/client.dcn0.glance.keyring --conf /etc/ceph/dcn0.conf -p images ls -l

echo "- Use qemu-img info on rbd path of image ID on central ceph cluster"
sudo qemu-img info rbd:images/image-$ID

# I think there's a problem because the images don't show up with ^ 

# Todo: get locations and set them with 'glance location-add'

if [ $CINDER -eq 1 ]; then
    # Use (working) cinder to show how the above commands should look
    echo -e "\n\n"
    echo "- Use Cinder to contrast RBD and qemu-img info on volumes pool"
    VOLID=$(openstack volume show test-volume -f value -c id)
    if [[ ! -z $VOLID ]]; then
	echo "- Found existing Cinder volume: $VOLID"
    else
	echo "- Creating 1 GB Cinder volume"
	openstack volume create --size 1 test-volume
	echo "sleeping 20 seconds"
	sleep 20
    fi
    echo "- Use RBD to list volumes on central"
    sudo podman exec ceph-mon-`hostname` rbd -p volumes ls -l

    echo "- Use qemu-img info on rbd path of volume ID on central ceph cluster"
    sudo qemu-img info rbd:volumes/volume-$VOLID
fi
