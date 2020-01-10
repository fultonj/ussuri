#!/usr/bin/env bash
NIC=1
REPO=1
INSTALL=1
CEPH_PREP=1
CONTAINERS=1

export FETCH=/tmp/ceph_ansible_fetch

if [[ $NIC -eq 1 ]]; then
    DEV=eth0
    IP=192.168.24.254
    if [[ $(ip a s $DEV | grep $IP | wc -l) -eq 0 ]]; then
        echo "Assigning $IP to $DEV"
        DST=/tmp/ifcfg-$DEV
        echo "DEVICE=eth0" >> $DST
        echo "BOOTPROTO=static" >> $DST
        echo "ONBOOT=yes" >> $DST
        echo "TYPE=Ethernet" >> $DST
        echo "PREFIX=24" >> $DST
        echo "IPADDR=$IP" >> $DST
        sudo mv -f $DST /etc/sysconfig/network-scripts/ifcfg-$DEV
        sudo ifup eth0
    fi
fi

if [[ $REPO -eq 1 ]]; then
    if [[ ! -d ~/rpms ]]; then mkdir ~/rpms; fi
    url=https://trunk.rdoproject.org/centos7/current/
    rpm_name=$(curl $url | grep python2-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = ".rpm" } ; { print $1 }')
    rpm=$rpm_name.rpm
    curl -f $url/$rpm -o ~/rpms/$rpm
    if [[ -f ~/rpms/$rpm ]]; then
	sudo yum install -y ~/rpms/$rpm
	sudo -E tripleo-repos current-tripleo-dev ceph
	sudo yum repolist
	sudo yum update -y
    else
	echo "$rpm is missing. Aborting."
	exit 1
    fi
fi

if [[ $INSTALL -eq 1 ]]; then
    sudo yum install -y python-tripleoclient ceph-ansible
fi

if [[ $CEPH_PREP -eq 1 ]]; then
    sudo yum install -y lvm2 util-linux
    if [[ ! -d $FETCH ]]; then
	mkdir $FETCH
    fi
    bash ceph/fake_disks.sh
fi

if [[ $CONTAINERS -eq 1 ]]; then
    openstack tripleo container image prepare default \
              --output-env-file $HOME/containers-env-file.yaml
fi
