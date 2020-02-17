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

- Apply [glance patch](patch_glance/) to glance container image
  (because the merged glance change is not yet in TripleO upstream)
- Use the following unmerged TripleO patches:
  - https://review.opendev.org/#/c/704373
  - https://review.opendev.org/#/c/704374

<!--
- Tag nodes with [ironic.sh](ironic.sh)
- [control-plane/deploy.sh](control-plane/deploy.sh)
- [dcn0/deploy.sh](dcn0/deploy.sh)
- Use [dcnN.sh](dcnN.sh) to deploy dcn1 (or as many as you like)
-->
