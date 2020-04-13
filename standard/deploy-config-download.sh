#!/bin/bash

COMPUTE=0
HEAT=1
DOWN=1
CONF=1

STACK=overcloud
DIR=config-download

export ANSIBLE_CONFIG=/home/stack/ansible.cfg
if [[ ! -e $ANSIBLE_CONFIG ]]; then
    bash /home/stack/ussuri/ansible_cfg.sh
fi

source ~/stackrc
# -------------------------------------------------------
if [[ $COMPUTE -eq 1 ]]; then
    # tag 3 ceph nodes as compute nodes
    for i in 5; do
        #k=$(($i-3))
        k=0
        openstack baremetal node set oc0-ceph-$i \
                  --property capabilities="node:0-compute-$k,boot_option:local"
        openstack baremetal node show oc0-ceph-5 | grep properties
    done
fi
# -------------------------------------------------------
if [[ $HEAT -eq 1 ]]; then
    if [[ ! -d ~/templates ]]; then
        ln -s /usr/share/openstack-tripleo-heat-templates templates
    fi
    time openstack overcloud deploy \
         --stack $STACK \
         --templates ~/templates/ \
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
         -e ~/ussuri/standard/overrides.yaml \
         --stack-only \
         --libvirt-type qemu 2>&1 | tee -a ~/install-overcloud.log

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
    if [[ -d $DIR ]]; then rm -rf $DIR; fi
    openstack overcloud config download \
              --name $STACK \
              --config-dir $DIR
    if [[ ! -d $DIR ]]; then
	echo "tripleo-config-download cmd didn't create $DIR"
    else
	pushd $DIR
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

    #echo "about to execute the following plays:"
    #ansible-playbook $DIR/deploy_steps_playbook.yaml --list-tasks

    echo "Running ansible with ANSIBLE_CONFIG=$ANSIBLE_CONFIG"
    time ansible-playbook-3 \
	 -v \
	 --ssh-extra-args "-o StrictHostKeyChecking=no" --timeout 240 \
	 --become \
	 -i $DIR/inventory.yaml \
         --private-key $DIR/ssh_private_key \
	 $DIR/deploy_steps_playbook.yaml

         # Just re-run ceph
         # -e gather_facts=true -e @$DIR/global_vars.yaml \
         # --tags external_deploy_steps \
    
         # Test validations
         # --tags opendev-validation-ceph
    
         # Pick up after good ceph install (need to test this)
         # --tags step2,step3,step4,step5,post_deploy_steps,external --skip-tags ceph

fi
