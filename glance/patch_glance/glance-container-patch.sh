#!/bin/bash

case "$1" in
    import)
        # https://review.opendev.org/#/c/667132
        PATCH=import-multi-stores
        REFSPEC=refs/changes/32/667132/25
        ;;

    copy)
        # https://review.opendev.org/#/c/696457
        # not tested using this method
        PATCH=copy-existing-image
        REFSPEC=refs/changes/57/696457/18
        ;;

    *)
        PATCH=import-multi-stores
        REFSPEC=refs/changes/32/667132/25
        #echo "Usage: $0 {copy|import}"
        #exit 1
esac

RAND=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 7 ; echo '')
echo $RAND > RAND

echo "Uploading new glance container called $PATCH-$RAND"
# -------------------------------------------------------
# Wrapper to avoid maintaining two copies of containers.yaml
INIT="../../init/"
# Use existing files
if [[ -e $INIT/containers.yaml ]]; then
    cp $INIT/containers.yaml containers.yaml
else
    echo "Error: missing file: $INIT/containers.yaml"
    exit 1
fi
# -------------------------------------------------------
# This rlies on modifications to the copied in containers.yaml

#import-multi-stores: https://review.opendev.org/#/c/667132
#copy-existing-image: https://review.opendev.org/#/c/696457

cat <<EOF > containers_tail
    excludes: [glance-api]
  - push_destination: 192.168.24.1:8787
    set:
      name_prefix: centos-binary
      namespace: docker.io/tripleomaster
      tag: current-tripleo
    includes:
    - glance-api
    modify_role: tripleo-modify-image
    modify_append_tag: "-$PATCH-$RAND"
    modify_vars:
      tasks_from: dev_install.yml
      source_image: docker.io/tripleomaster/centos-binary-glance-api:current-tripleo
      refspecs:
        -
          project: glance
          refspec: $REFSPEC
EOF

cat containers_tail >> containers.yaml
rm containers_tail
cat containers.yaml
# -------------------------------------------------------
echo "Starting 'openstack tripleo container image prepare' ..."
time sudo openstack tripleo container image prepare \
     -e containers.yaml --output-env-file ~/containers-env-file.yaml

echo "Is the $PATCH version in ~/containers-env-file.yaml"
grep $PATCH ~/containers-env-file.yaml

echo "Testing a podman pull of centos-binary-glance-api:current-tripleo-$PATCH"
sudo podman pull 192.168.24.1:8787/tripleomaster/centos-binary-glance-api:current-tripleo-$PATCH-$RAND

sudo podman images | grep glance
