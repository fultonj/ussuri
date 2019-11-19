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
# K nodes per deployment
if [[ -z $2 ]]; then
    K=3
else
    K=$2
fi
if [[ $K -lt 1 ]]; then
    echo "Only positive integers for the number of nodes per deployment please"
    exit 1
fi

if [[ $IRONIC -eq 1 ]]; then
    source ~/stackrc
    NODES=()
    for UUID in $(openstack baremetal node list -f value -c UUID -c Name \
                            -c "Provisioning State" \
                      | grep available | grep ceph | awk {'print $1'}); do
        NODES+=( $UUID )
    done
    if [[ $(($N*$K)) -gt ${#NODES[@]} ]]; then
        echo "fail: $(($N*$K)) nodes requested but only ${#NODES[@]} nodes are available"
        exit 1
    else
        echo "$(($N*$K)) node(s) requested and ${#NODES[@]} nodes are available"
    fi
    # count up to N or K based with their lowercase versions
    for n in $(seq 1 $N); do # sites loop (we already have dcn0, start at 1)
        for k in $(seq 0 $(($K-1))); do # nodes loop (0 indexed so subtract 1)
            echo "node:$n-ceph-$k for ${NODES[$k]}"
            openstack baremetal node set ${NODES[$k]} \
                      --property capabilities="node:$n-ceph-$k,boot_option:local"
        done            
    done
fi

for n in $(seq 1 $N); do
    deploy="dcn$n"
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
    sed s/"0-ceph-%index%"/"$n-ceph-%index%"/g -i $deploy/overrides.yaml
    cp dcn0/deploy.sh $deploy/deploy.sh
    sed s/dcn0/$deploy/g -i $deploy/deploy.sh
    cp dcn0/glance_cache.yaml $deploy/glance_cache.yaml
    pushd $deploy
    bash deploy.sh
    popd
done
