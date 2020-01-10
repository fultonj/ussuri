#!/bin/bash

NAME=ceph
SVC=openstack
POOL=images
CONF=/etc/ceph/$NAME.conf
ID=client.$SVC
KEY=/etc/ceph/$NAME.client.$SVC.keyring
RBD="rbd --conf $CONF --id $ID --keyring $KEY --cluster cent0"
DATA=$(date | md5sum | cut -c-12)

if [[ ! -e /usr/bin/rbd ]]; then
    sudo yum install -y ceph-common
fi
if [[ ! -e /usr/bin/crudini ]]; then
    sudo yum install -y crudini
fi

MON=$(crudini --get $CONF global 'mon host' | awk 'BEGIN { FS = ":" } ; { print $2 }')
ping -q -c 1 $MON > /dev/null 2>&1
if [[ $? -gt 0 ]]; then
    echo "Unable to ping host: $MON exiting"
    exit 1
fi

# read
sudo $RBD ls $POOL
exit 0
# write
sudo $RBD create --size 1024 $POOL/$DATA

# read
sudo $RBD ls $POOL

# delete
sudo $RBD rm $POOL/$DATA
