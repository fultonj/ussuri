#!/bin/bash

if [ -z "$1" ]; then
    NAME=ceph
else
    NAME=$1
fi

echo "Testing if $HOSTNAME can be a client to the ceph cluster called $NAME"

# -----
# Uncomment one of the following for POD
# If you're not using podman and do want to install the RBD client
# POD=""
# If you're using podman and don't want to install the RBD client
POD="podman exec ceph-mon-$HOSTNAME"
# -----

# Set to >0 if you want to test pinging the monitor host
PING=0

SVC=glance
POOL=images
CONF=/etc/ceph/$NAME.conf
ID=$SVC
KEY=/etc/ceph/$NAME.client.$SVC.keyring
RBD="$POD rbd --conf $CONF --keyring $KEY --id $ID --cluster $NAME"
DATA=$(date | md5sum | cut -c-12)

if [[ -z POD ]]; then
    if [[ ! -e /usr/bin/rbd ]]; then
        sudo yum install -y ceph-common
    fi
fi
if [[ $PING -gt 0 ]]; then
    if [[ ! -e /usr/bin/crudini ]]; then
        sudo yum install -y crudini
    fi
    MON=$(crudini --get $CONF global 'mon host')
    ping -q -c 1 $MON > /dev/null 2>&1
    if [[ $? -gt 0 ]]; then
        echo "Unable to ping host: $MON exiting"
        exit 1
    fi
fi

echo -e "\nCeph commands will be like:\n"
echo "sudo $RBD ls $POOL"

echo -e "\nRead (pool might be empty)\n"
sudo $RBD ls $POOL

echo -e "\nWrite $DATA to $POOL\n"
sudo $RBD create --size 1024 $POOL/$DATA

echo -e "\nRead list data in $POOL\n"
sudo $RBD ls $POOL

echo -e "\nDelete $DATA from $POOL\n"
sudo $RBD rm $POOL/$DATA
