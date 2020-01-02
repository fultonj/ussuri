#!/usr/bin/env bash
# known issues: assumes you have run ironic.sh and glance-container-patch.sh

KILL=1

source ~/stackrc
if [[ $KILL -eq 1 ]]; then
    if [[ $(openstack stack list | wc -l) -gt 1 ]]; then
        echo "Destroying the following deployments"
        openstack stack list
        for STACK in $(openstack stack list -f value -c "Stack Name"); do
            pushd $STACK
            bash ../../kill.sh $STACK
            popd
        done
    fi
fi

echo "Standing up control-plane deployment"
pushd control-plane
bash deploy.sh
popd

echo "Verify control-plane is working"
pushd validate
bash validate.sh control
if [[ $? -gt 0 ]]; then
    echo "Execution of use-controlplane.sh on first controller failed. Aborting."
    exit 1
fi
popd

echo "Standing up dcn0 deployment"
pushd dcn0
bash deploy.sh
if [[ $? -gt 0 ]]; then
    echo "DCN deployment failed. Aborting."
    exit 1
fi
popd

# echo "Standing up dcn1 deployment"
# bash dcnN.sh

pushd ansible
bash run.sh
if [[ $? -gt 0 ]]; then
    echo "Ansibile post-tripleo configuration failed. Aborting."
    exit 1
fi
popd

echo "Configure control-plane for testing"
pushd validate
bash validate.sh
popd
