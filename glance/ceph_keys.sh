#!/usr/bin/env bash
# 
# Based on input of first argument $1 (1,2,3) does one of the following:
#
#   1. make control-plane/ceph_keys.yaml with CephExtraKeys
#   2. make ~/dcn_ceph_keys.yaml with CephExtraKeys and CephExternalMultiConfig
#   3. make control-plane/ceph_keys_update.yaml with CephExternalMultiConfig
#
# as described in https://bugzilla.redhat.com/show_bug.cgi?id=1808424
# so that the deployer can do the following:
#
# A. Deploy central using CephExtraKeys to create a ceph key for the central
#    ceph pools which may by used by any DCN node
#
# B. Deploy dcn0 with it's own ceph cluster and the ability to use the key
#    from stepA to access a second ceph cluster via CephExternalMultiConfig
#    and also create a key with CephExtraKeys that can access the ceph
#    pools on the dcn0 ceph cluster
#
# C. Deploy dcn1 with it's own ceph cluster and the ability to use the key
#    from stepA to access a second ceph cluster via CephExternalMultiConfig
#    and also create a key with CephExtraKeys that can access the ceph
#    pools on the dcn1 ceph cluster
#
# D. Update central and pass CephExternalMultiConfig with the keys created
#    from steps B and C so it can write to the ceph pools at the DCN sites
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
        TARGET='/home/stack/dcn_ceph_keys.yaml'
        PARAMS=('CephExtraKeys' 'CephExternalMultiConfig')
        STACKS=('control-plane')
        ;;
    3)
        TARGET='control-plane/ceph_keys_update.yaml'
        PARAMS=('CephExternalMultiConfig')
        STACKS=('dcn0' 'dcn1')
        ;;
    *)
        echo "Usage: $0 {1|2|3} where each option does one of the following:"
        echo "1. create control-plane/ceph_keys.yaml with CephExtraKeys"
        echo "2. create ~/dcn_ceph_keys.yaml with CephExtraKeys and CephExternalMultiConfig"
        echo "3. create control-plane/ceph_keys_update.yaml with CephExternalMultiConfig"
        ;;
esac

echo "Creating $TARGET with ${PARAMS[@]}"

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
          osd: "profile rbd pool=vms, profile rbd pool=volumes, profile rbd pool=images"
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
            osd: "profile rbd pool=vms, profile rbd pool=volumes, profile rbd pool=images"
          key: "$KEY"
          mode: "0600"
      dashboard_enabled: false
      ceph_conf_overrides:
        client:
          keyring: /etc/ceph/$CLUSTER.client.external.keyring
EOF
}

function random_key() {
    # from https://github.com/ceph/ceph-deploy/blob/master/ceph_deploy/new.py#L21
    # the following works with both py2 and py3
    local MYKEY=$(python3 -c 'import os,struct,time,base64; key = os.urandom(16); header = struct.pack("<hiih", 1, int(time.time()), 0, len(key)) ; print(base64.b64encode(header + key).decode())')
    echo $MYKEY
}

function get_from_yaml() {
    # In retrospect I should have written this entire shell script in
    # Python but for now I'll just tape this together so I can move on
    local MYVAR=$(python3 get_from_yaml.py -y $FILE -k $MYKEY)
    echo $MYVAR
}

prep_target
for PARAM in "${PARAMS[@]}"; do
    NAME="client.external"
    if [[ $PARAM == 'CephExtraKeys' ]]; then
        KEY=$(random_key)
        make_extra_keys
    fi
    if [[ $PARAM == 'CephExternalMultiConfig' ]]; then
        echo "Each entry in CephExternalMultiConfig will come from ${STACKS[@]}"
        prep_multi_config
        for STACK in "${STACKS[@]}"; do
            FILE="$(pwd)/$STACK/config-download/ceph-ansible/group_vars/all.yml"
            MYKEY=fsid
            FSID=$(get_from_yaml)
            MYKEY=cluster
            CLUSTER=$(get_from_yaml)
            MYKEY=key
            KEY=$(get_from_yaml)
            FILE="$(pwd)/$STACK/config-download/inventory.yaml"
            MYKEY=external_cluster_mon_ips
            EXTERNAL_CLUSTER_MON_IPS=$(get_from_yaml)
            make_multi_config
        done
    fi
done

if [[ -e $TARGET ]]; then
    ls -l $TARGET
    cat $TARGET
    #rm -v $TARGET
fi
