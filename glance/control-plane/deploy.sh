#!/bin/bash

HEAT=1
DOWN=1
CONF=1

STACK=control-plane
DIR=config-download

export ANSIBLE_CONFIG=/home/stack/ansible.cfg
if [[ ! -e $ANSIBLE_CONFIG ]]; then
    bash /home/stack/ussuri/ansible_cfg.sh
fi

source ~/stackrc
# -------------------------------------------------------
if [[ ! -e ~/control_plane_roles.yaml ]]; then
    openstack overcloud roles generate Controller ComputeHCI -o ~/control_plane_roles.yaml
fi
# -------------------------------------------------------
if [[ $HEAT -eq 1 ]]; then
    if [[ ! -d ~/templates ]]; then
        ln -s /usr/share/openstack-tripleo-heat-templates templates
    fi
    time openstack overcloud deploy \
         --stack $STACK \
         --templates ~/templates/ \
         -r ~/control_plane_roles.yaml \
         -n ~/ussuri/network-data.yaml \
         -e ~/templates/environments/net-multiple-nics.yaml \
         -e ~/templates/environments/network-isolation.yaml \
         -e ~/templates/environments/network-environment.yaml \
         -e ~/templates/environments/disable-telemetry.yaml \
         -e ~/templates/environments/low-memory-usage.yaml \
         -e ~/templates/environments/enable-swap.yaml \
         -e ~/templates/environments/podman.yaml \
         -e ~/templates/environments/ceph-ansible/ceph-ansible.yaml \
         -e ~/containers-env-file.yaml \
         -e ~/domain.yaml \
         -e ~/ussuri/glance/control-plane/ceph.yaml \
         -e ~/ussuri/glance/control-plane/ceph_keys.yaml \
         -e ~/ussuri/glance/control-plane/overrides.yaml \
         --stack-only \
         --libvirt-type qemu 2>&1 | tee -a ~/install-overcloud.log

    # For stack updates when central glance will use dcn{0,1} ceph clusters
    # -e ~/ussuri/glance/control-plane/ceph_keys_update.yaml \
    # -e ~/ussuri/glance/control-plane/glance_update.yaml \
    
    # remove --stack-only to make DOWN and CONF unnecessary
fi
# -------------------------------------------------------
if [[ $DOWN -eq 1 ]]; then
    echo "Get status of $STACK from Heat"
    STACK_STATUS=$(openstack stack list -c "Stack Name" -c "Stack Status" \
	-f value | grep $STACK | awk {'print $2'});
    if [[ ! ($STACK_STATUS == "CREATE_COMPLETE" || 
                 $STACK_STATUS == "UPDATE_COMPLETE") ]]; then
	echo "Exiting. Status of $STACK is $STACK_STATUS"
	exit 1
    fi
    if [[ -d $DIR ]]; then
        echo "Remove old $DIR"
        rm -rf $DIR;
    fi
    openstack overcloud config download \
              --name $STACK \
              --config-dir $DIR
    if [[ ! -d $DIR ]]; then
	echo "tripleo-config-download cmd didn't create $DIR"
    else
	pushd $DIR
        echo "Create inventory"
	tripleo-ansible-inventory --static-yaml-inventory inventory.yaml --stack $STACK
	if [[ ! -e inventory.yaml ]]; then
	    echo "No inventory. Giving up."
	    exit 1
	fi
        echo "Ensure ~/.ssh/id_rsa_tripleo exists"
	if [[ ! -e ~/.ssh/id_rsa_tripleo ]]; then
            cp ~/.ssh/id_rsa ~/.ssh/id_rsa_tripleo
        fi
        echo "Test ansible ping"
        echo "Running ansible with ANSIBLE_CONFIG=$ANSIBLE_CONFIG"
	ansible -i inventory.yaml all -m ping
	popd
        echo "export ANSIBLE_CONFIG=/home/stack/ansible.cfg"
	echo "pushd $DIR"
	echo 'ansible -i inventory.yaml all -m shell -b -a "hostname"'
    fi
fi
# -------------------------------------------------------
if [[ $CONF -eq 1 ]]; then
    if [[ ! -d $DIR ]]; then
	echo "tripleo-config-download cmd didn't create $DIR"
        exit 1;
    fi
    echo "Running ansible with ANSIBLE_CONFIG=$ANSIBLE_CONFIG"
    time ansible-playbook-3 \
	 -v \
	 --become \
	 -i $DIR/inventory.yaml \
	 $DIR/deploy_steps_playbook.yaml

    # Do not use these yet for updates to central; need to identify glance tags
    # For stack updates when central will use dcn{0,1} ceph clusters:
    # -e gather_facts=true -e @$DIR/global_vars.yaml \
    # --tags external_deploy_steps \
    # --tags tag_for_glance? \

fi
