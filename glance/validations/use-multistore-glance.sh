#!/bin/bash
RC=../control-plane/control-planerc
if [[ -e $RC ]]; then
    source $RC
else
    echo "$RC is missing. abort."
    exit 1
fi

echo "Testing import-multi-stores and copy-existing-image"
# -------------------------------------------------------
echo "Check if glance is working"
glance image-list
if [[ $? -gt 0 ]]; then
    echo "Aborting. Not even 'glance image-list' works."
    exit 1
fi
# -------------------------------------------------------
# Get image if missing
NAME=cirros
IMG=cirros-0.4.0-x86_64-disk.img
URL=http://download.cirros-cloud.net/0.4.0/$IMG
if [ ! -f $IMG ]; then
    echo "Could not find qemu image $img; downloading a copy."
    curl -L -# $URL > $IMG
fi
# -------------------------------------------------------
# Upload raw version of image
# RAW=$(echo $IMG | sed s/img/raw/g)
# if [ ! -f $RAW ]; then
#     echo "Could not find raw image $raw; converting."
#     if [[ ! -e /bin/qemu-img ]]; then
#         sudo yum install qemu-img -y
#     fi
#     qemu-img convert -f qcow2 -O raw $IMG $RAW
#     # only refer to RAW image
#      if [ -f $RAW ]; then
#          IMG=$RAW
#      fi
# fi
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
glance --verbose image-create-via-import --disk-format qcow2 --container-format bare --name $NAME
ID=$(openstack image show $NAME -c id -f value)

echo "- Upload image data to staging"
glance --verbose image-stage $ID --file $IMG
if [[ $? -gt 0 ]]; then
    echo "Aborting. Unable to: glance image-stage $ID --file $IMG";
    exit 1;
fi

echo "- Get token"
TOKEN=$(openstack token issue -f value -c id)

echo "- Get glance endpoint"
ENDPOINT=$(openstack endpoint list -c "Service Name" -c "Interface" -c "URL" \
                     -f value | grep glance | grep public | awk {'print $3'})

# -------------------------------------------------------
echo "Import image $NAME into both central and dcn0 (import-multi-stores) with curl"

set -o xtrace
curl -g -i -X POST $ENDPOINT/v2/images/$ID/import -H "User-Agent: python-glanceclient" -H "Content-Type: application/json" -H "X-Auth-Token: $TOKEN" -d '{"method": {"name": "glance-direct"}, "stores": ["default_backend", "dcn0"]}'
set +o xtrace

openstack image show $NAME

echo "Looking at glance tasks"
glance task-list | head -5

echo "Show newest task"
TASK_ID=$(glance task-list | head -4 | egrep "success|processing" | awk {'print $2'})
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

if [[ -e ~/stackrc ]]; then
    source ~/stackrc
    CONTROLLER=$(openstack server list -f value -c Name -c Networks | grep controller | awk {'print $2'} | sed s/ctlplane=//g)
fi
if [[ ! -z CONTROLLER ]]; then
    echo "- Use RBD to list images on central"
    CMD_CENTRAL="sudo podman exec ceph-mon-\$(hostname) rbd --cluster central -p images ls -l"
    ssh heat-admin@$CONTROLLER "$CMD_CENTRAL"
    echo "- Use RBD to list images on dcn0"
    CMD_DCN="sudo podman exec ceph-mon-\$(hostname) rbd --id glance --keyring /etc/ceph/dcn0.client.glance.keyring --conf /etc/ceph/dcn0.conf -p images ls -l"    
    ssh heat-admin@$CONTROLLER "$CMD_DCN"
fi

source $RC
echo ""
echo "Copy image $NAME from central into dcn1 (copy-existing-image) with curl"
echo ""

set -o xtrace
curl -g -i -X POST $ENDPOINT/v2/images/$ID/import -H "User-Agent: python-glanceclient" -H "Content-Type: application/json" -H "X-Auth-Token: $TOKEN" -d '{"method": {"name": "copy-image"}, "stores": ["dcn1"]}'
set +o xtrace

echo "Waiting 5 seconds for image to finish copying..."
sleep 5

if [[ ! -z CONTROLLER ]]; then
    echo "- Use RBD to list images on dcn1"
    CMD_DCN="sudo podman exec ceph-mon-\$(hostname) rbd --id glance --keyring /etc/ceph/dcn1.client.glance.keyring --conf /etc/ceph/dcn1.conf -p images ls -l"    
    ssh heat-admin@$CONTROLLER "$CMD_DCN"
fi

echo "Show properties of $ID to see the stores"
openstack image show $ID | grep properties
