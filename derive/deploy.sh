#!/bin/bash

HEAT=1
DOWN=0
CONF=0

STACK=overcloud
DIR=config-download

source ~/stackrc
# -------------------------------------------------------
# export ANSIBLE_CONFIG=/home/stack/ansible.cfg
# if [[ ! -e $ANSIBLE_CONFIG ]]; then
#     bash /home/stack/ussuri/ansible_cfg.sh
#     if [[ ! -e $ANSIBLE_CONFIG ]]; then
#         echo "Unable to create $ANSIBLE_CONFIG"
#         exit 1;
#     fi
# fi
#         --override-ansible-cfg $ANSIBLE_CONFIG \
# -------------------------------------------------------
if [[ -e install-overcloud.log ]]; then
    if [[ ! -d log ]]; then mkdir log; fi
    gzip install-overcloud.log
    mv install-overcloud.log.gz log/install-overcloud.log.gz.$(date +%s)
fi

if [[ ! -e ~/derive_roles.yaml ]]; then
    openstack overcloud roles generate Controller ComputeHCI -o ~/derive_roles.yaml
fi
# -------------------------------------------------------
# `openstack overcloud -v` should be passed along as
# `ansible-playbook -vv` for any usage of Ansible (the
# OpenStack client defaults to no -v being 1 verbosity
# and --quiet being 0)
# -------------------------------------------------------
if [[ $HEAT -eq 1 ]]; then
    time openstack overcloud -v deploy \
         --stack $STACK \
         --templates /usr/share/openstack-tripleo-heat-templates/ \
         -r ~/derive_roles.yaml \
         -p /usr/share/openstack-tripleo-heat-templates/plan-samples/plan-environment-derived-params.yaml \
         -e /usr/share/openstack-tripleo-heat-templates/environments/disable-telemetry.yaml \
         -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml \
         -e /usr/share/openstack-tripleo-heat-templates/environments/enable-swap.yaml \
         -e /usr/share/openstack-tripleo-heat-templates/environments/podman.yaml \
         -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
         -e ~/containers-env-file.yaml \
         -e ~/domain.yaml \
         -e ~/ussuri/derive/overrides.yaml \
         --stack-only \
         --libvirt-type qemu 2>&1 | tee -a /home/stack/ussuri/derive/install-overcloud.log

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
