#!/bin/bash

if [[ ! -e control-planerc ]]; then
    echo "control-planerc is missing. aborting."
    exit 1
fi
source control-planerc
# if you cannot issue a token the control plane isn't working
openstack token issue -f value -c id
# pass the return code of token issue
exit $?
