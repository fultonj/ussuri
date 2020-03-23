# Glance with Multiple Ceph Clusters

## Deployment Topology

The goal is to be able to ask the control-plane Glance to upload an
image to multiple DCN sites so they can be COW fast-booted on that
site. The [virtual hardware](../tripleo-lab/overrides.yml#L12) will
be deployed in the following stacks and roles.

```
+------------------+
| control-plane    |    GlanceBackend: RBD | CephClusterName: central
+------------------+
| oc0-controller-0 |    Controller (Glance + Mon)
| oc0-controller-1 |    Controller (Glance + Mon)
| oc0-controller-2 |    Controller (Glance + Mon)
| oc0-ceph-0       |    ComputeHCI (Nova + OSD)
+------------------+

+------------------+
| dcn0             |    Standard DCN + GlanceBackend: RBD | CephClusterName: dcn0
+------------------+
| oc0-ceph-1       |    DistributedComputeHCI (Glance + Nova + Mon + OSD)
| oc0-ceph-2       |    DistributedComputeHCIScaleUp (HaProxy + Nova + OSD)
+------------------+

+------------------+
| dcn1             |    Standard DCN + GlanceBackend: RBD | CephClusterName: dcn1
+------------------+
| oc0-ceph-3       |    DistributedComputeHCI (Glance + Nova + Mon + OSD)
| oc0-ceph-4       |    DistributedComputeHCIScaleUp (HaProxy + Nova + OSD)
+------------------+
```

## How to deploy it with TripleO

- Tag nodes with [ironic.sh](ironic.sh)
- Run [master.sh](master.sh) which does the following:
  - Create `control-plane/ceph_keys.yaml` with `ceph_keys.sh 1`
  - Deploy control-plane with [control-plane/deploy.sh](control-plane/deploy.sh)
  - Create `~/control-plane-export.yaml` with [export.sh](export.sh)
  - Create `~/dcn_ceph_keys.yaml` with `ceph_keys.sh 2`
  - Deploy dcn0 with [dcn0/deploy.sh](dcn0/deploy.sh)
  - Deploy dcn1 with [dcnN.sh](dcnN.sh)
  - Create `control-plane/ceph_keys_update.yaml` with `ceph_keys.sh 3`
- Update control-plane/deploy.sh to use `control-plane/ceph_keys_update.yaml`
- Update control-plane/deploy.sh to use [control-plane/glance_update.yaml](control-plane/glance_update.yaml)
- Re-run control-plane/deploy.sh

## Verifications

The scripts below maybe used to: 

- Import an image into the central, dcn0 and dcn1 locations
- Boot an instance and create a volume in the central location
- Boot an instance and create a volume in the dcn0 or dcn1 location
- Verify all necessary Ceph client configurations

### Glance

- Use [use-multistore-glance.sh](use-multistore-glance.sh) to import
  an image into both `default_backend` and `dcn0`
  with [import-multi-stores](https://review.opendev.org/#/c/667132)
  and then copy that image to `dcn1`
  with [copy-existing-image](https://review.opendev.org/#/c/696457).
  A successful example looks
  like [use-multistore-glance.log](use-multistore-glance.log).

### Cinder/Nova on Central

- [use-central.sh](use-central.sh)

### Cinder/Nova on DCN

- [use-dcn.sh](use-dcn.sh)
- To test dcn1, update AZ from "dcn0" to "dcn1"

### Ceph

- Verify any DCN node at $IP can use the central ceph cluster
```
scp ../multiceph/test_ceph_client.sh heat-admin@$IP:/home/heat-admin/
ssh $IP "bash /home/heat-admin/test_ceph_client.sh central"
```

- Verify the control-plane node at $IP can use any DCN ceph cluster
```
scp ../multiceph/test_ceph_client.sh heat-admin@$IP:/home/heat-admin/
ssh $IP "bash /home/heat-admin/test_ceph_client.sh dcn0"
ssh $IP "bash /home/heat-admin/test_ceph_client.sh dcn1"
```

- Were multiple glance backends configured at central Controller or dcn DistributedComputeHCI at $IP?
```
ssh $IP "sudo tail /var/lib/config-data/puppet-generated/glance_api/etc/glance/glance-api.conf"
```
