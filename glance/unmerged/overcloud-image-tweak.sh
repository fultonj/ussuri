#!/usr/bin/env bash
PULL=1
UPDATE=1
PUSH=1
# -------------------------------------------------------
SSH_ENV='ssh_config'
IMAGE='overcloud-full.qcow2'
IMG_PATH='/home/stack/overcloud_imgs'
PASSWORD='redhat'
# -------------------------------------------------------
if [ $PULL -eq 1 ]; then
    if [[ ! -f $SSH_ENV ]]; then
        echo "FAIL: $SSH_ENV is missing."
        exit 1
    fi

    ssh -A -F $SSH_ENV stack@undercloud "uname -a"
    if [[ $? -gt 0 ]]; then
        echo "FAIL: Unable to SSH into stack@undercloud"
        exit 1
    fi
    if [[ ! $(rpm -q libguestfs-tools) ]]; then
        echo "virt-customize is not installed. Attempting to install."
        sudo yum install libguestfs-tools -y 
    fi
    if [[ ! $(rpm -q unzip) ]]; then
        echo "unzip is not installed. Attempting to install."
        sudo yum install unzip -y 
    fi

    echo "Looking for $IMAGE on undercloud"
    ssh -A -F $SSH_ENV stack@undercloud "ls -lh $IMG_PATH/$IMAGE" 2> /dev/null

    HAS_IMAGE=$(ssh -A -F $SSH_ENV stack@undercloud "ls $IMG_PATH/$IMAGE | wc -l" 2> /dev/null)
    if [[ "$HAS_IMAGE" == "0" ]]; then
        echo "FAIL: $IMAGE is not on undercloud."
        exit 1
    fi

    echo "Pulling down copy of $IMAGE"
    scp -F $SSH_ENV stack@undercloud:$IMG_PATH/$IMAGE . 2> /dev/null
fi
# -------------------------------------------------------
if [ $UPDATE -eq 1 ]; then

    if [[ ! -e $IMAGE ]]; then
        echo "FAIL: $IMAGE is missing (use PULL)"
        exit 1
    fi

    echo "Download puppet-tripleo"
    curl -L https://github.com/openstack/puppet-tripleo/archive/master.zip \
         -o puppet-tripleo.zip
    unzip puppet-tripleo.zip
    mv puppet-tripleo-master tripleo
    tar cvfz tripleo.tar.gz tripleo/*
    rm -fr puppet-tripleo.zip puppet-tripleo/ tripleo/
    MY_PUPPET=tripleo.tar.gz
    
    echo "Installing $MY_PUPPET in /etc/puppet/modules/ on $IMAGE"
    if [[ ! -e $MY_PUPPET ]]; then
        echo "FAIL: $MY_PUPPET is missing"
    fi
    virt-customize -a $IMAGE --upload $MY_PUPPET:/
    CMD='tar xf /tripleo.tar.gz; rm -f /tripleo.tar.gz /etc/puppet/modules/tripleo ; mv /tripleo /etc/puppet/modules/'
    virt-customize --selinux-relabel -a $IMAGE --run-command "$CMD"
    rm -f $MY_PUPPET

    echo "Setting root password to $PASSWORD"
    virt-customize -a $IMAGE --root-password password:$PASSWORD

    echo "Updating SSH to not do reverse DNS lookup"
    virt-customize -a $IMAGE --run-command "echo 'UseDNS no' >> /etc/ssh/sshd_config"
fi
# -------------------------------------------------------
if [ $PUSH -eq 1 ]; then
    echo "Pushing up new copy of $IMAGE"
    scp -F $SSH_ENV $IMAGE stack@undercloud:$IMG_PATH/$IMAGE

    #echo "Deleting local copy of $IMAGE"
    #rm -f $IMAGE

    #echo "Uploading new image to Undercloud Glance (with tripleo-lab script)"
    #ssh -A -F $SSH_ENV stack@undercloud "bash push-oc-img"
fi
