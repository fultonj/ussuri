#!/bin/bash

INV=config-download/ceph-ansible/inventory.yml
if [[ ! -e $INV ]]; then
    echo "Missing config download inventory: $INV"
    exit 1
fi

ANS="ansible -i $INV CephAll[0] -m shell -b"
FSID=$($ANS -a "cat /etc/ceph/ceph.conf" | grep "fsid" | awk 'BEGIN { FS = "= " } ; { print $2 }')
KEY=$($ANS -a "cat /etc/ceph/ceph.client.openstack.keyring" | grep key | awk 'BEGIN { FS = "= " } ; { print $2 }')
IPS=$($ANS -a "cat /etc/ceph/ceph.conf" | grep "mon host" | awk 'BEGIN { FS = "= " } ; { print $2 }')

cat <<EOF > external_ceph.yaml
parameter_defaults:
  CephClusterFSID: "$FSID"
  CephClientKey: "$KEY"
  CephExternalMonHost: "$IPS"
EOF
wc -l external_ceph.yaml
cat external_ceph.yaml

