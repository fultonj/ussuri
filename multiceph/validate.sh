#!/bin/bash

# Can $CONTROLLER use ceph cluster(s) named in $CLUSTERS?

#CLUSTERS="ceph0"
CLUSTERS="ceph ceph0 ceph1"
FILE=test_ceph_client.sh
source ~/stackrc
CONTROLLER=$(openstack server list -c Networks -c Name -f value | grep controller-0 | awk {'print $2'} | sed s/ctlplane=//g)

scp -q -o "StrictHostKeyChecking no" $FILE heat-admin@$CONTROLLER:/home/heat-admin/

for C in $CLUSTERS; do
  ssh -q -o "StrictHostKeyChecking no" heat-admin@$CONTROLLER "bash test_ceph_client.sh $C"
done
