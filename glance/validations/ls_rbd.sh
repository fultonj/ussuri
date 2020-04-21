#!/usr/bin/env bash

AZ=0
POOLS=1
POOL=volumes
STACKS="control-plane,dcn0,dcn1"

RC=../control-plane/control-planerc
export ANSIBLE_DEPRECATION_WARNINGS=0
export ANSIBLE_TRANSFORM_INVALID_GROUP_CHARS=ignore
export ANSIBLE_LOG_PATH="/dev/null"
export ANSIBLE_STDOUT_CALLBACK=null
INV=inventory.yml
if [[ ! -e $INV ]]; then
    source ~/stackrc
    
    if [[ ! -e $INV ]]; then
        tripleo-ansible-inventory --static-yaml-inventory $INV --stack $STACKS
        # ansible -i inventory.yml all -m ping
    fi
fi
source $RC

if [ $AZ -eq 1 ]; then
    echo "Volume availability zones"
    openstack availability zone list --volume
    echo "Volume services"
    openstack volume service list --long
fi

if [ $POOLS -eq 1 ]; then
    echo "Collecting $POOL for $STACKS"
    ansible-playbook -i $INV ls_rbd.yml -e save_output=true -e pool=$POOL
    for REPORT in $(ls ls_rbd*.txt); do
        echo "-------------------------------------------------------"
        cat $REPORT
        echo -e "\n"
        rm -f $REPORT
    done
fi
