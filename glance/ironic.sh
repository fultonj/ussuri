#!/bin/bash

# tag nodes in Ironic as described in README.md

source ~/stackrc
STACK=0
# oc0-controller-0 -->  Controller
# oc0-controller-1 -->  Controller
# oc0-controller-2 -->  Controller
for i in 0 1 2; do
    NAME=oc0-controller-$i
    openstack baremetal node set $NAME \
              --property capabilities="node:$STACK-controller-$i,boot_option:local"
    echo $NAME
    openstack baremetal node show $NAME -f value | grep cap
done

# oc0-ceph-0       -->  ComputeHCI
NAME="oc0-ceph-0"
echo $NAME
openstack baremetal node set $NAME \
          --property capabilities="node:$STACK-ceph-0,boot_option:local"
openstack baremetal node show $NAME -f value | grep cap


STACK=1
# oc0-ceph-1       -->  DistributedComputeHCI
# oc0-ceph-3       -->  DistributedComputeHCI
k=0
for i in 1 3; do
    NAME=oc0-ceph-$i
    openstack baremetal node set $NAME \
              --property capabilities="node:$STACK-dcn-hci-$k,boot_option:local"
    echo $NAME
    openstack baremetal node show $NAME -f value | grep cap
    k=$((k+1))
    STACK=$((STACK+1))
done


STACK=1
# oc0-ceph-2       -->  DistributedComputeHCIScaleUp
# oc0-ceph-4       -->  DistributedComputeHCIScaleUp
k=0
for i in 2 4; do
    NAME=oc0-ceph-$i
    openstack baremetal node set $NAME \
              --property capabilities="node:$STACK-dcn-hci-scaleup-$k,boot_option:local"
    echo $NAME
    openstack baremetal node show $NAME -f value | grep cap
    k=$((k+1))
    STACK=$((STACK+1))
done
