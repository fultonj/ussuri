#!/bin/bash
source ~/stackrc

openstack server list -f value -c Name -c Networks \
    | sed -e s/ctlplane=//g -e s/control-plane/central/g \
    | grep -v scaleout | egrep "distributed|controller" > /tmp/nodes

for AZ in central dcn0 dcn1; do
    echo $AZ
    IP=$(grep $AZ /tmp/nodes | awk {'print $2'})
    CMD="sudo podman exec ceph-mon-\$(hostname) rbd --id glance --keyring /etc/ceph/$AZ.client.glance.keyring --conf /etc/ceph/$AZ.conf -p images ls -l"
    #echo $CMD
    ssh -o LogLevel=ERROR $IP "$CMD"
    echo ""
done

rm -f /tmp/nodes
