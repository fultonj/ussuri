#!/usr/bin/env bash

KILL=1

source ~/stackrc
if [[ $KILL -eq 1 ]]; then
    if [[ $(openstack stack list | wc -l) -gt 1 ]]; then
        echo "Destroying the following deployments"
        openstack stack list
        for STACK in $(openstack stack list -f value -c "Stack Name"); do
            bash ../kill.sh $STACK
        done
    fi
fi

echo "Standing up control-plane deployment"
pushd control-plane
bash deploy.sh
popd

echo "Standing up dcn0 deployment"
pushd dcn0
bash deploy.sh
popd

echo "Standing up dcn1 deployment"
bash dcnN.sh

echo "Testing"
bash validate.sh
