#!/bin/bash

export HOST=ceph1
export TAG=4.0.6

echo "Configuring $HOST so ceph-ansible can be run on it"

ping -q -c 1 $HOST > /dev/null 2>&1
if [[ $? -gt 0 ]]; then
    echo "Unable to ping host: $HOST exiting"
    exit 1
fi

if [[ ! -d ceph-ansible ]]; then
    echo "Downloading ceph-ansible $TAG"
    URL=https://codeload.github.com/ceph/ceph-ansible/tar.gz/v$TAG
    curl $URL -o $TAG.tar.gz
    tar xf $TAG.tar.gz
    rm -f $TAG.tar.gz
    ln -s ceph-ansible-$TAG ceph-ansible
fi

echo "Creating inventory from inventory.sample for $HOST"
cp inventory.sample ceph-ansible/inventory
sed s/HOST/$HOST/g -i ceph-ansible/inventory 

echo "Creating ceph-ansible/group_vars/all.yml from all.yml"
cp all.yml ceph-ansible/group_vars/all.yml
sed s/HOST/$HOST/g -i ceph-ansible/group_vars/all.yml

ansible -i ceph-ansible/inventory -m ping all
if [[ $? -gt 0 ]]; then
    echo "Unable to ansible ping host: $HOST exiting"
    exit 1
fi

# take care of prerequisites on the host
ansible -b -i ceph-ansible/inventory -m yum -a "name=podman,lvm2 state=present" all
scp fake_disks.sh stack@$HOST:/tmp/fake_disks.sh
ssh stack@$HOST "bash /tmp/fake_disks.sh"

echo "Ready to run ceph-ansible. Do the following:"
echo ""
echo "cd ceph-ansible"
echo "ansible-playbook -b -i inventory site-container.yml.sample"
echo ""
