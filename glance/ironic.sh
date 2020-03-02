#!/bin/bash

# tag nodes in Ironic as described in README.md
source ~/stackrc

declare -A MAP
MAP[oc0-controller-0]="0-controller-0"  # Controller
MAP[oc0-controller-1]="0-controller-1"  # Controller
MAP[oc0-controller-2]="0-controller-2"  # Controller
MAP[oc0-ceph-0]="0-ceph-0"              # ComputeHCI
MAP[oc0-ceph-1]="0-dcn-hci-0"           # DistributedComputeHCI
MAP[oc0-ceph-2]="0-dcn-hci-scaleup-0"   # DistributedComputeHCIScaleUp
MAP[oc0-ceph-3]="1-dcn-hci-0"           # DistributedComputeHCI
MAP[oc0-ceph-4]="1-dcn-hci-scaleup-0"   # DistributedComputeHCIScaleUp

for K in "${!MAP[@]}"; do
    echo "$K ---> ${MAP[$K]}";
    openstack baremetal node set $K \
              --property capabilities="node:${MAP[$K]},boot_option:local"
    openstack baremetal node show $K -f value | grep cap 
done
