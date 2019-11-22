#!/usr/bin/env bash

IRONIC=1

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
    k=$(($n+1))
    if [[ -d $deploy ]]; then
        echo "A directory named $deploy already exists. Aborting."
        exit 1
    fi
    echo "Creating $deploy (deployment $n out of $N)"
    
    mkdir $deploy
    cp dcn0/ceph.yaml $deploy/ceph.yaml
    sed s/dcn0/$deploy/g -i $deploy/ceph.yaml
    cp dcn0/overrides.yaml $deploy/overrides.yaml
    sed s/dcn0/$deploy/g -i $deploy/overrides.yaml
    sed s/"1-ceph-%index%"/"$k-ceph-%index%"/g -i $deploy/overrides.yaml
    cp dcn0/deploy.sh $deploy/deploy.sh
    sed s/dcn0/$deploy/g -i $deploy/deploy.sh
    pushd $deploy
    bash deploy.sh
    popd
done
