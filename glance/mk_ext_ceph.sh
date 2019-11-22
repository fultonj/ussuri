#!/bin/bash

CEPH=$1
if [[ -z $CEPH ]]; then CEPH=dcn0; fi
echo "Extracting ceph client information for ceph cluster: $CEPH"

INV=$CEPH/config-download/ceph-ansible/inventory.yml
if [[ ! -e $INV ]]; then
    echo "Missing config download inventory: $INV"
    exit 1
fi

ANS="ansible -i $INV DistributedComputeHCI[0] -m shell -b"
FSID=$($ANS -a "cat /etc/ceph/$CEPH.conf" | grep "fsid" | awk 'BEGIN { FS = "= " } ; { print $2 }')
KEY=$($ANS -a "cat /etc/ceph/$CEPH.client.openstack.keyring" | grep key | awk 'BEGIN { FS = "= " } ; { print $2 }')
IPS=$($ANS -a "cat /etc/ceph/$CEPH.conf" | grep "mon host" | awk 'BEGIN { FS = "= " } ; { print $2 }')

cat <<EOF > external_ceph.yaml
parameter_defaults:
  CephClusterName: $CEPH
  CephClusterFSID: "$FSID"
  CephClientKey: "$KEY"
  CephExternalMonHost: "$IPS"
EOF
echo ""
cat external_ceph.yaml

