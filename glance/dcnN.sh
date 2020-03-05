#!/usr/bin/env bash

# N deployments
if [[ -z $1 ]]; then
    N=1
else
    N=$1
fi
if [[ $N == 0 ]]; then
    echo "No additional dcn sites requested"
    exit 0
fi
if [[ $N -lt 1 ]]; then
    echo "Only positive integers for the number of deployments please"
    exit 1
fi

for n in $(seq 1 $N); do
    deploy="dcn$n"
    if [[ -d $deploy ]]; then
        echo "A directory named $deploy already exists. Aborting."
        exit 1
    fi
    echo "Creating $deploy (deployment $n out of $N)"    

    if [[ -e /home/stack/dcn_ceph_keys.yaml ]]; then
        echo "Backing up ~/dcn_ceph_keys.yaml into previous deployment"
        k=$(($n-1))
        cp /home/stack/dcn_ceph_keys.yaml dcn${k}/dcn_ceph_keys.yaml.bak
    fi
    echo "(Re)Generating ~/dcn_ceph_keys.yaml with new CephExtraKeys"
    bash ceph_keys.sh 2

    mkdir $deploy
    cp dcn0/ceph.yaml $deploy/ceph.yaml
    sed s/dcn0/$deploy/g -i $deploy/ceph.yaml
    cp dcn0/overrides.yaml $deploy/overrides.yaml
    sed s/dcn0/$deploy/g -i $deploy/overrides.yaml
    sed s/"0-dcn-hci"/"$n-dcn-hci"/g -i $deploy/overrides.yaml
    cp dcn0/nova-az.yaml $deploy/nova-az.yaml
    sed s/dcn0/$deploy/g -i $deploy/nova-az.yaml
    cp dcn0/glance.yaml $deploy/glance.yaml
    sed s/dcn0/$deploy/g -i $deploy/glance.yaml
    cp dcn0/deploy.sh $deploy/deploy.sh
    sed s/dcn0/$deploy/g -i $deploy/deploy.sh
    pushd $deploy
    bash deploy.sh
    popd
done
