#!/usr/bin/env bash
# 
# Based on input of first argument $1 (1,2,3) does one of the following:
#
#   1. make control-plane/ceph_keys.yaml with CephExtraKeys
#   2. make dcn0/ceph_keys.yaml with CephExtraKeys and CephExternalMultiConfig
#   3. make control-plane/ceph_keys_update.yaml with CephExternalMultiConfig
#
# as described in https://bugzilla.redhat.com/show_bug.cgi?id=1808424
# so that the deployer can do the following:
#
# A. Deploy central using CephExtraKeys to create a ceph key for the central
#    glance pool which may by used by any DCN node
#
# B. Deploy dcn0 with it's own ceph cluster and the ability to use the key
#    from stepA to access a second ceph cluster via CephExternalMultiConfig
#    and also create a key with CephExtraKeys that can access the glance
#    pool on the dcn0 ceph cluster
#
# C. Deploy dcn1 with it's own ceph cluster and the ability to use the key
#    from stepA to access a second ceph cluster via CephExternalMultiConfig
#    and also create a key with CephExtraKeys that can access the glance
#    pool on the dcn1 ceph cluster
#
# D. Update central and pass CephExternalMultiConfig with the keys created
#    from steps B and C so it can write to the glance pools at the DCN sites
#    via CephExternalMultiConfig
#
# The above is another way to implement the pattern described in
# https://bugzilla.redhat.com/show_bug.cgi?id=1760941

case "$1" in
    1)
        TARGET='control-plane/ceph_keys.yaml'
        PARAMS=('CephExtraKeys')
        ;;
    2)
        TARGET='dcn0/ceph_keys.yaml'
        PARAMS=('CephExtraKeys' 'CephExternalMultiConfig')
        SOURCES=('control-plane')
        ;;
    3)
        TARGET='control-plane/ceph_keys_update.yaml'
        PARAMS=('CephExternalMultiConfig')
        SOURCES=('dcn0' 'dcn1')
        ;;
    *)
        echo "Usage: $0 {1|2|3} where each option does one of the following:"
        echo "1. create control-plane/ceph_keys.yaml with CephExtraKeys"
        echo "2. create dcn0/ceph_keys.yaml with CephExtraKeys and CephExternalMultiConfig"
        echo "3. create control-plane/ceph_keys_update.yaml with CephExternalMultiConfig"
        ;;
esac

echo "Creating $TARGET with ${PARAMS[@]}"

function random_key() {
    # from https://github.com/ceph/ceph-deploy/blob/master/ceph_deploy/new.py#L21
    # the following works with both py2 and py3
    local MYKEY=$(python -c 'import os,struct,time,base64; key = os.urandom(16); header = struct.pack("<hiih", 1, int(time.time()), 0, len(key)) ; print(base64.b64encode(header + key).decode())')
    echo $MYKEY
}

function prep_target() {
cat <<EOF > $TARGET
parameter_defaults:
EOF
}

function make_extra_keys() {
cat <<EOF >> $TARGET
  CephExtraKeys:
      - name: "$NAME"
        caps:
          mgr: "allow *"
          mon: "profile rbd"
          osd: "profile rbd pool=images"
        key: "$KEY"
        mode: "0600"
EOF
}

function prep_multi_config() {
cat <<EOF >> $TARGET
  CephExternalMultiConfig:
EOF
}

function make_multi_config() {
cat <<EOF >> $TARGET
    - cluster: "$CLUSTER"
      fsid: "$FSID"
      external_cluster_mon_ips: "$EXTERNAL_CLUSTER_MON_IPS"
      keys:
        - name: "$NAME"
          caps:
            mgr: "allow *"
            mon: "profile rbd"
            osd: "profile rbd pool=images"
          key: "$KEY"
          mode: "0600"
      dashboard_enabled: false
EOF
}

prep_target
for PARAM in "${PARAMS[@]}"; do
    NAME="client.glance"
    if [[ $PARAM == 'CephExtraKeys' ]]; then
        KEY=$(random_key)
        make_extra_keys
    fi
    if [[ $PARAM == 'CephExternalMultiConfig' ]]; then
        echo "Each entry in CephExternalMultiConfig will come from ${SOURCES[@]}"
        prep_multi_config
        # start todo(fultonj) make this real
        # for SOURCE in "${SOURCES[@]}"; do
        #     CLUSTER=# read from stack $SOURCE
        #               for stack control-plane it's central
        #     KEY=# read from stack $SOURCE 
        #     FSID=# read from stack $SOURCE 
        #     EXTERNAL_CLUSTER_MON_IPS=# read from stack $SOURCE 
        #     # make_multi_config
        # done
        # end todo(fultonj) make this real

        # start todo(fultonj) delete this
        # These values are just an example. The real ones need to be read from
        # the exported deployment plan of each stack in SOURCES. A future update
        # will create and read the exported deployment plan(s)
        echo "WARNING: CephExternalMultiConfig currently uses hard-coded params"
        CLUSTER="dcn0"
        KEY="AQD3ql5eAAAAABAAt3jgexzAVCxCuZDmA1CrdA=="
        FSID="af25554b-42f6-4d2b-9b9b-d08a1132d3e8"
        EXTERNAL_CLUSTER_MON_IPS="172.18.0.42,172.18.0.6,172.18.0.8"
        make_multi_config
        CLUSTER="dcn1"
        KEY="AQDjrV5eAAAAABAAetHTk9p2JojFt6ILmFbvvw=="
        FSID="e721f158-fc34-4df0-8ae5-f04fd9ef3dc6"
        EXTERNAL_CLUSTER_MON_IPS="172.17.0.5,172.17.0.6,172.17.0.7"
        make_multi_config
        # end todo(fultonj) delete this
    fi
done

if [[ -e $TARGET ]]; then
    ls -l $TARGET
    cat $TARGET
    # rm -v $TARGET
fi
