#!/bin/bash

# tag nodes in Ironic as described in README.md
source ~/stackrc

declare -A MAP
MAP[oc0-controller-2]="2-controller-0"  # Controller
MAP[oc0-ceph-5]="2-ceph-0"              # ComputeHCI

for K in "${!MAP[@]}"; do
    echo "$K ---> ${MAP[$K]}";
    openstack baremetal node set $K \
              --property capabilities="node:${MAP[$K]},boot_option:local"
    openstack baremetal node show $K -f value | grep cap 
done
