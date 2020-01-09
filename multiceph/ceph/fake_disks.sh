#!/usr/bin/env bash

for pkg in util-linux lvm2; do
    rpm -q $pkg > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "failure: please yum install $pkg"
        exit 1
    fi
done

i=0
for LV in /dev/vg2/db-lv2 /dev/vg2/data-lv2; do
    if [[ -e $LV ]]; then
        i=$(($i+1 ))
    fi
done
if [[ $i -eq 2 ]]; then
    echo "It looks like you already have the Ceph disks you need."
    exit 0
fi
if [[ $i -eq 0 ]]; then
    sudo dd if=/dev/zero of=/var/lib/ceph-osd.img bs=1 count=0 seek=7G
    sudo losetup /dev/loop3 /var/lib/ceph-osd.img
    sudo lsblk

    sudo pvcreate /dev/loop3
    sudo vgcreate vg2 /dev/loop3
    sudo lvcreate -n data-lv2 -l 1194 vg2
    sudo lvcreate -n db-lv2 -l 597 vg2
    sudo lvs
else
    echo "The disks for this exercise are not configured as expected."
    echo "Try running purge_ceph.sh and then re-run $0"
    exit 1
fi
