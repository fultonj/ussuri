#!/usr/bin/env bash
# Assumes you have run added any unmerged changes and run ironic.sh
KILL=1
CONTROL=1
EXPORT=1
DCN0=1
DCN1=1
CONTROLUP=1
# -------------------------------------------------------
source ~/stackrc
if [[ $KILL -eq 1 ]]; then
    if [[ $(openstack stack list | wc -l) -gt 1 ]]; then
        echo "Destroying the following deployments"
        openstack stack list
        for STACK in $(openstack stack list -f value -c "Stack Name"); do
            pushd $STACK
            bash ../kill.sh $STACK
            popd
        done
    fi
    echo "Syncing Containers"
    bash ../init/containers.sh
fi
# -------------------------------------------------------
if [[ $CONTROL -eq 1 ]]; then
    echo "Generating control-plane/ceph_keys.yaml"
    bash ceph_keys.sh 1
    if [[ ! -e control-plane/ceph_keys.yaml ]]; then
        echo "Failure: ceph_keys.sh 1"
        exit 1
    fi

    echo "Standing up control-plane deployment"
    pushd control-plane
    bash deploy.sh
    popd

    echo "Verify control-plane is working"
    RC=control-plane/control-planerc
    if [[ -e $RC ]]; then
        source $RC
        echo "Attempting to issue token from control-plane"
        openstack token issue -f value -c id
        if [[ $? -gt 0 ]]; then
            echo "Unable to issue token. Aborting."
            exit 1
        fi
        # Use undercloud by default
        source ~/stackrc
    else
        echo "$RC is missing. abort."
        exit 1
    fi
fi
# -------------------------------------------------------
if [[ $EXPORT -eq 1 ]]; then
    echo "Create ~/control-plane-export.yaml with export.sh"
    bash export.sh
    if [[ ! -e ~/control-plane-export.yaml ]]; then
        echo "Unable to create ~/control-plane-export.yaml. Aborting."
        exit 1
    fi
    echo "Create ~/dcn_ceph_keys.yaml with ceph_keys.sh 2"
    bash ceph_keys.sh 2
    if [[ ! -e ~/dcn_ceph_keys.yaml ]]; then
        echo "Failure: ceph_keys.sh 2"
        exit 1
    fi
fi
# -------------------------------------------------------
if [[ $DCN0 -eq 1 ]]; then
    echo "Standing up dcn0 deployment"
    pushd dcn0
    bash deploy.sh
    if [[ $? -gt 0 ]]; then
        echo "DCN deployment failed. Aborting."
        exit 1
    fi
    popd
fi
# -------------------------------------------------------
if [[ $DCN1 -eq 1 ]]; then
    echo "Standing up dcn1 deployment"
    bash dcnN.sh
fi
# -------------------------------------------------------
if [[ $CONTROLUP -eq 1 ]]; then
    echo "Create control-plane/ceph_keys_update.yaml with ceph_keys.sh 3"
    bash ceph_keys.sh 3
    if [[ ! -e control-plane/ceph_keys_update.yaml ]]; then
        echo "Failure: ceph_keys.sh 3"
        exit 1
    fi
    echo ""
    echo "Three more steps required to continue:"
    echo ""
    echo "1. Update control-plane/deploy.sh to use control-plane/ceph_keys_update.yaml"
    echo "2. Update control-plane/deploy.sh to use control-plane/glance_update.yaml"
    echo "3. Re-run control-plane/deploy.sh"
    echo "You may then test the deployment with use-multistore-glance.sh"
fi
