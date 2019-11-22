# Glance Experiments

Experiments of deploying Glance within DCN contexts.

## Glance Cache vs Glance Multistore

### Glance Cache

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

### Glance Multistore

One way to add multistore Glance and have central compute nodes (and
an external ceph cluster if desired) is the following:

```
control-plane [Glance end point (images + volumes pool on external rbd)]
|
+-- External Ceph Cluster [images, volumes, vms] (deployed first)
|
+-- central [DistributedCompute (vms pool on external rbd)]
|
|
(distance)
|
+-- dcn0 [DistributedComputeHCI + glance-api (local ceph: images, volumes, vms)]
|
+-- dcn1 [DistributedComputeHCI + glance-api (local ceph: images, volumes, vms)]
|
...
+-- dcnN [DistributedComputeHCI + glance-api (local ceph: images, volumes, vms)]
```

In the above the goal is to be able to ask the control-plane Glance
end point to copy any set of images to any DCN site so that they can
be COW fast-booted on that site. There are other possible variations
at the central site not requiring an external Ceph cluster.

One way to arrange my [virtual hardware](../tripleo-lab/overrides.yml#L12)
to try something like the above is the following three stacks:

```
+------------------+
| control-plane    |    GlanceBackend: RBD | CephClusterName: central
+------------------+
| oc0-controller-0 |    Controller
| oc0-controller-1 |    Controller
| oc0-controller-2 |    Controller
| oc0-ceph-0       |    CephStorage
| oc0-ceph-1       |    CephStorage
| oc0-ceph-2       |    CephStorage
| oc0-ceph-3       |    Compute
+------------------+

+------------------+
| dcn0             |    Standard DCN + GlanceBackend: RBD | CephClusterName: dcn0
+------------------+
| oc0-ceph-4       |    DistributedComputeHCI + Glance
+------------------+

+------------------+
| dcn1             |    Standard DCN + GlanceBackend: RBD | CephClusterName: dcn1
+------------------+
| oc0-ceph-5       |    DistributedComputeHCI + Glance
+------------------+
```

## How to deploy it

- Tag nodes with [ironic.sh](ironic.sh)
- [control-plane/deploy.sh](control-plane/deploy.sh)
- [dcn0/deploy.sh](dcn0/deploy.sh)
- Extract Ceph client information from dcn0 [mk_ext_ceph.sh](mk_ext_ceph.sh)
- Use [dcnN.sh](dcnN.sh) to deploy dcn1 (or as many as you like)
- Extract Ceph client information from dcn1 [mk_ext_ceph.sh dcn1](mk_ext_ceph.sh)

You've now completed steps 1-4 of 
[RFE BZ 1760941](https://bugzilla.redhat.com/show_bug.cgi?id=1760941#c0).
As [step 5](https://blueprints.launchpad.net/tripleo/+spec/multiple-external-ceph)
isn't yet implemented we need to do this step manually.
At least the extract steps above gave you the input you'd need for step 5.

### Manual Steps to configure multiple Ceph clients

- Todo: document these steps

### Manual Steps to configure Glance multiple RBD backends

- Todo: document these steps

## Next

Write TripleO patches to automate the manual steps in this environment.
