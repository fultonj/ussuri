# Glance Experiments

Experiments of deploying Glance with in DCN contexts.

## Glance Cache

The [dcn](../dcn) example fits glance-cache into the [TripleO Docs DCN Example](https://docs.openstack.org/project-deploy-guide/tripleo-docs/latest/features/distributed_compute_node.html#example-dcn-deployment-with-pre-provisioned-nodes-shared-networks-and-multiple-stacks) by doing something like the following:

```
control-plane [glance w/ swift backend]
|
+-- central (hci/all) [glance-api cache]
|
|
(distance)
|
+-- dcn0 (hci/all) [glance-api cache]
|
+-- dcn1 (hci/all) [glance-api cache]
|
...
+-- dcnN (hci/all) [glance-api cache]
```

Though the [dcn](../dcn) example calls each edge site "dcn0, dcn1,
dcnN" adding another "dcn" but calling it "central" is trivial. It's
the same architecture except central shares the same geographical
location as the control-plane stack.

## Glance Multistore

One way to add multistore Glance and have central compute nodes (and
an external ceph cluster if desired) is the following:

```
control-plane [glance-api end point (images + volumes pool on external rbd)]
|
+-- External Ceph Cluster [images, volumes, vms] (deployed first)
|
+-- central [computes (vms/volumes pool on external rbd)]
|
|
(distance)
|
+-- dcn0 (hci/all) [glance-api local ceph: images, volumes, vms]
|
+-- dcn1 (hci/all) [glance-api local ceph: images, volumes, vms]
|
...
+-- dcnN (hci/all) [glance-api local ceph: images, volumes, vms]
```

In the above the goal is to be able to ask control-plane Glance end
point to copy any set of images to any DCN site so that they can be
COW fast-booted on that site. 

One way to arrange my [virtual hardware](../tripleo-lab/overrides.yml#L12)
to try something like the above is the following 4 stacks:

```
+------------------+
| control-plane    |    GlanceBackend: RBD | CephClusterName: central
+------------------+
| oc0-controller-0 |    Controller
| oc0-controller-1 |    Controller
| oc0-controller-2 |    Controller
| oc0-ceph-0       |    CephAllStorage
| oc0-ceph-1       |    CephAllStorage
| oc0-ceph-2       |    CephAllStorage
| oc0-ceph-3       |    Compute
+------------------+

+------------------+
| dcn0             |    Standard DCN + GlanceBackend: RBD
+------------------+
| oc0-ceph-4       |    DistributedComputeHCI + Glance
+------------------+

+------------------+
| dcn1             |    Standard DCN + GlanceBackend: RBD
+------------------+
| oc0-ceph-5       |    DistributedComputeHCI + Glance
+------------------+
```
