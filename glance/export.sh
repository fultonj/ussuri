#!/bin/bash

source ~/stackrc

if [ $# -eq 0 ]; then
    STACK=control-plane
else
    STACK=$1
fi

if [[ -e ~/${STACK}-export.yaml ]]; then
    echo "Removing exported control plane data (~/${STACK}-export.yaml)"
    rm -f ~/${STACK}-export.yaml
fi
openstack overcloud export \
          --config-download-dir $STACK/config-download/ \
          --stack $STACK \
          --output-file ~/${STACK}-export.yaml
if [[ ! -e ~/${STACK}-export.yaml ]]; then
    echo "Unable to create ~/${STACK}-export.yaml. Aborting."
    exit 1
fi
