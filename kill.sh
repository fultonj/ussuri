#!/usr/bin/bash

source ~/stackrc

if [[ -z $1 ]]; then
    CLOUD=overcloud
else
    CLOUD=$1    
fi
echo "Deleting heat stack, deployment plan, and config-download for \"$CLOUD\""

# delete heat stack
openstack stack delete $CLOUD --wait --yes

# delete deployment plan 
openstack overcloud delete $CLOUD --yes
# yes, the above also deletes the heat stack but not as quickly

if [[ -e ansible.log ]]; then
    rm -v -f ansible.log
fi
if [[ -d config-download ]]; then
    rm -v -rf config-download
fi

# delete exported control-plane file if it exsits
if [[ -e ~/control-plane-export.yaml ]]; then
    rm -v ~/control-plane-export.yaml
fi

# delete all RC files
find . -name ${CLOUD}rc -exec rm -f {} \;
