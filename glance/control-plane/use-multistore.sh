#!/bin/bash

STORES="central,dcn0"
if [[ ! -e control-planerc ]]; then
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
echo "- Create image"
glance image-create-via-import --disk-format raw --container-format bare --name $NAME
ID=$(openstack image show $NAME -c id -f value)

echo "- Upload image data to staging"
glance image-stage $ID --file $RAW

echo "- Get token"
TOKEN=$(openstack token issue -f value -c id)

echo "- Get glance endpoint"
ENDPOINT=$(openstack endpoint list -c "Service Name" -c "Interface" -c "URL" \
                     -f value | grep glance | grep public | awk {'print $3'})

if [[ $PATCH -eq "import-multi-stores" ]]; then
    echo "- Import $NAME into multiple stores $STORES with curl"
    set -o xtrace
    curl -g -i -X POST $ENDPOINT/v2/images/$ID/import -H "x-image-meta-store: $STORES" -H "User-Agent: python-glanceclient" -H "Content-Type: application/json" -H "X-Auth-Token: $TOKEN" -d '{"method": {"name": "glance-direct"}}'
    set +o xtrace
fi

if [[ $PATCH -eq "copy-existing-image" ]]; then
    echo "- Copy $NAME between multiple stores $STORES with curl"
    set -o xtrace
    curl -g -i -X POST $ENDPOINT/v2/images/$ID/import -H "x-image-meta-store: $STORES" -H "User-Agent: python-glanceclient" -H "Content-Type: application/json" -H "X-Auth-Token: $TOKEN" -d '{"method": {"name": "copy-image"}}'
    set +o xtrace
fi
