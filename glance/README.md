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
+-- central [computes (vms pool on external rbd)]
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
to try the above is the following five stacks:

```
+------------------+
| central-ceph     |
+------------------+
| oc0-ceph-0       |
| oc0-ceph-1       |
| oc0-ceph-2       |
+------------------+

+------------------+
| control-plane    |
+------------------+
| oc0-controller-0 |
| oc0-controller-1 |
| oc0-controller-2 |
+------------------+

+------------------+
| central-compute  |
+------------------+
| oc0-ceph-3       |
+------------------+

+------------------+
| dcn0             |
+------------------+
| oc0-ceph-4       |
+------------------+

+------------------+
| dcn1             |
+------------------+
| oc0-ceph-5       |
+------------------+
```
