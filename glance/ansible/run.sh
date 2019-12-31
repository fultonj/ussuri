#!/usr/bin/env bash

source ~/stackrc
STACKS="control-plane,dcn0,dcn1"
export ANSIBLE_DEPRECATION_WARNINGS=0
export ANSIBLE_LOG_PATH="ansible.log"
INV=inventory.yml
if [[ ! -e $INV ]]; then
    tripleo-ansible-inventory --static-yaml-inventory $INV --stack $STACKS
    ansible -i inventory.yml all -m ping
fi

ansible-playbook -i inventory.yml site.yml $@
