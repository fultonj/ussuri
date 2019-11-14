#!/bin/bash

COMPUTE=0
HEAT=1
DOWN=1
CONF=1

STACK=overcloud
DIR=config-download
#DIR=$(date +%b%d_%H.%M)

source ~/stackrc
# -------------------------------------------------------
if [[ $COMPUTE -eq 1 ]]; then
    # tag 3 ceph nodes as compute nodes
    for i in 5 4 3; do
        k=$(($i-3))
        openstack baremetal node set oc0-ceph-$i \
          --property capabilities="node:0-compute-$k,boot_option:local"
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
         -e ~/overcloud-0-yml/container-cli.yaml \
         -e ~/domain.yaml \
         -e ~/ussuri/standard/overrides.yaml \
         --stack-only \
         --libvirt-type qemu 2>&1 | tee -a ~/install-overcloud.log

    # remove --stack-only to make DOWN and CONF unnecessary
fi
# -------------------------------------------------------
if [[ $DOWN -eq 1 ]]; then
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
        cp -a ~/.ssh/id_rsa ssh_private_key
	ansible --private-key ssh_private_key \
	    --ssh-extra-args "-o StrictHostKeyChecking=no" \
	    -i inventory.yaml all -m ping
	popd
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

    # include library/roles from tripleo-validations, tripleo-common, tripleo-ansible
    export ANSIBLE_ROLES_PATH="$ANSIBLE_ROLES_PATH:/usr/share/openstack-tripleo-common/:/usr/share/openstack-tripleo-validations/roles:/usr/share/ansible/roles:/usr/share/ceph-ansible/roles"
    export ANSIBLE_LIBRARY="$ANSIBLE_LIBRARY:/usr/share/openstack-tripleo-validations/library:/usr/share/ansible-modules/:/usr/share/ansible/plugins/modules/:/usr/share/ceph-ansible/library"
    export DEFAULT_ACTION_PLUGIN_PATH="$DEFAULT_ACTION_PLUGIN_PATH:/usr/share/ansible/plugins/action:/usr/share/ceph-ansible/plugins/actions"
    export DEFAULT_CALLBACK_PLUGIN_PATH="$DEFAULT_CALLBACK_PLUGIN_PATH:/usr/share/ansible/plugins/callback:/usr/share/ceph-ansible/plugins/callback"
    export DEFAULT_FILTER_PLUGIN_PATH="$DEFAULT_FILTER_PLUGIN_PATH:/usr/share/ansible/plugins/filter:/usr/share/ceph-ansible/plugins/filter"
    export DEFAULT_MODULE_UTILS_PATH="$DEFAULT_MODULE_UTILS_PATH:/usr/share/ansible/plugins/module_utils"
    export ANSIBLE_LOG_PATH="ansible.log"
    echo "NEXT: $(date)" >> ansible.log

    time ansible-playbook-3 \
	 -v \
	 --ssh-extra-args "-o StrictHostKeyChecking=no" --timeout 240 \
	 --become \
	 -i $DIR/inventory.yaml \
         --private-key $DIR/ssh_private_key \
         --skip-tags ceph \
	 $DIR/deploy_steps_playbook.yaml

         # -e validate_controllers_icmp=false \
         # -e validate_gateways_icmp=false \
         # -e validate_fqdn=false \
         # -e validate_ntp=false \
         # -e ping_test_ips=false \

         # Just re-run ceph
         # --tags external_deploy_steps

         # Test validations
         # --tags opendev-validation-ceph
    
         # Pick up after good ceph install (need to test this)
         # --tags step2,step3,step4,step5,post_deploy_steps,external --skip-tags ceph

fi