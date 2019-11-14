#!/bin/bash
source ~/stackrc
time sudo openstack tripleo container image prepare \
  -e ~/train/containers.yaml \
  --output-env-file ~/containers-env-file.yaml

#  -e ~/local_images.yaml \

curl -s http://192.168.24.1:8787/v2/_catalog | jq "."
