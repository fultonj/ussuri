#!/bin/bash

# tag nodes in Ironic as described in README.md

source ~/stackrc

# oc0-controller-0 -->  Controller
# oc0-controller-1 -->  Controller
# oc0-controller-2 -->  Controller
for i in 0 1 2; do
    NAME=oc0-controller-$i
    openstack baremetal node set $NAME \
              --property capabilities="node:0-controller-$i,boot_option:local"
    echo $NAME
    openstack baremetal node show $NAME -f value | grep cap
done

# oc0-ceph-3       -->  Compute
for i in 3; do
    k=$(($i-3))
    NAME=oc0-ceph-$i
    openstack baremetal node set $NAME \
              --property capabilities="node:0-compute-$k,boot_option:local"
    echo $NAME
    openstack baremetal node show $NAME -f value | grep cap
done

# oc0-ceph-0       -->  CephAllStorage
# oc0-ceph-1       -->  CephAllStorage
# oc0-ceph-2       -->  CephAllStorage
for i in 0 1 2; do
    NAME=oc0-ceph-$i
    openstack baremetal node set $NAME \
              --property capabilities="node:0-ceph-$i,boot_option:local"
    echo $NAME
    openstack baremetal node show $NAME -f value | grep cap
done

# oc0-ceph-4       -->  CephAllStorage
# oc0-ceph-5       -->  CephAllStorage
for i in 4 5; do
    k=$(($i-3))
    NAME=oc0-ceph-$i
    openstack baremetal node set $NAME \
              --property capabilities="node:$k-ceph-0,boot_option:local"
    echo $NAME
    openstack baremetal node show $NAME -f value | grep cap
done
