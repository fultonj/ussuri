#!/bin/bash
# Creates ~/ansible.cfg which uses tripleo-ansible checkouts from git

OOOA="/home/stack/tripleo-ansible/tripleo_ansible"
OOOV="/home/stack/tripleo-validations"
source ~/stackrc

echo "Create ansible.cfg"
openstack tripleo config generate ansible 
if [[ ! -e ~/ansible.cfg ]]; then
    echo "No ~/ansible.cfg. Giving up."
    exit 1
fi
echo "Replace /var/lib/mistral with /home/stack in ansible.cfg"
sed -i -e s_/var/lib/mistral_/home/stack_g ~/ansible.cfg

if [[ -d $OOOV ]]; then
    echo "Replace /usr/share/openstack-tripleo-validations with $OOOV"
    sed -i -e "s /usr/share/openstack-tripleo-validations ${OOOV} g" ~/ansible.cfg
fi

if [[ -d $OOOA ]]; then
    OOOA_ROLES="${OOOA}/roles"
    echo "Replace /home/stack/roles with $OOOA_ROLES"
    sed -i -e "s /home/stack/roles ${OOOA_ROLES} g" ~/ansible.cfg
    OOOA_PLUGINS="${OOOA}/ansible_plugins"
    echo "Replace /root/.ansible/plugins with $OOOA_PLUGINS"
    sed -i -e "s /root/.ansible/plugins ${OOOA_PLUGINS} g" ~/ansible.cfg
    echo "Replace ~/.ansible/plugins with $OOOA_PLUGINS"
    sed -i -e "s ~/.ansible/plugins ${OOOA_PLUGINS} g" ~/ansible.cfg
fi
