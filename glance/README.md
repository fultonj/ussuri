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

## How to deploy it with TripleO

- Apply upstream [glance patch](patch_glance/) to glance container image
- Tag nodes with [ironic.sh](ironic.sh)
- [control-plane/deploy.sh](control-plane/deploy.sh)
- [dcn0/deploy.sh](dcn0/deploy.sh)
- Use [dcnN.sh](dcnN.sh) to deploy dcn1 (or as many as you like)

You've now completed steps 1-4 of 
[RFE BZ 1760941](https://bugzilla.redhat.com/show_bug.cgi?id=1760941#c0).
As [step 5](https://blueprints.launchpad.net/tripleo/+spec/multiple-external-ceph)
isn't yet implemented in TripleO we need to do this step outside of TripleO.

### Steps outside of TripleO to configure multiple Ceph clients

Run [ansible/run.sh](ansible/run.sh) which will use
Ansible to do the following:

- Create a keyring on each of the DCN Ceph clusters which may be used
  to read/write to the images pool
- Install the keyring and Ceph configuration file for each DCN ceph
  cluster on the Central controller which runs Glance
- Test that the RBD command on the Central controller is able to use
  the installed keyring and configuration file to write to each DCN
  ceph cluster
- Modify Glance on the central controller to use the additional
  DCN RBD backends
- Modify Glance on the central controller and DCNs to support either
  [import-multi-stores](https://review.opendev.org/#/c/667132)
  or [copy-existing-image](https://review.opendev.org/#/c/696457).

#### What Glance changes are made by the playbook?

The following Glance configuration file is used by the glance_api container:

 `/var/lib/config-data/puppet-generated/glance_api/etc/glance/glance-api.conf`

Modifying it outside of TripleO is wrong (it's already managed by
puppet), but for this POC the playbook modifies this file as follows:

- Under `[DEFAULT]` adds `enabled_backends = central:rbd, dcn0:rbd,
  dcn1:rbd` and removes `registry_host=0.0.0.0`

`sudo crudini --set /var/lib/config-data/puppet-generated/glance_api/etc/glance/glance-api.conf DEFAULT enabled_backends central:rbd, dcn0:rbd, dcn1:rbd`

`sudo crudini --del /var/lib/config-data/puppet-generated/glance_api/etc/glance/glance-api.conf DEFAULT registry_host`

- Removes the entire default `[glance_store]` section (it will be replaced)
  
`sudo crudini --del /var/lib/config-data/puppet-generated/glance_api/etc/glance/glance-api.conf glance_store`

- Appends the following to the bottom of the file:

```
[glance_store]
stores=http,rbd
os_region_name=regionOne
default_backend = central

[central]
store_description = "central RBD backend"
rbd_store_pool = images
rbd_store_user = openstack
rbd_store_ceph_conf = /etc/ceph/ceph.conf

[dcn0]
store_description = "dcn0 RBD backend"
rbd_store_pool = images
rbd_store_user = dcn0.glance
rbd_store_ceph_conf = /etc/ceph/dcn0.conf

[dcn1]
store_description = "dcn1 RBD backend"
rbd_store_pool = images
rbd_store_user = dcn1.glance
rbd_store_ceph_conf = /etc/ceph/dcn1.conf
```

It then restarts the glance container:

 `sudo systemctl restart tripleo_glance_api.service`

It also updates each DCN nodes `glance-api.conf` and `nova.conf` to 
make the Nova query the local Glance on the DCN (not the central
Glance) and to make the local Glance's default backend the dcnN
ceph cluster. For example:

- glance-api.conf on dcn0
```
[glance_store]
default_backend=dcn0
```
- nova.conf on dcn0
```
[glance]
api_servers = http://172.16.13.212:9292
```
Where `172.16.13.212:9292` turns up a local Glance server and would be
consistent with the output of `netstat -an | grep 9292`. It then
restarts the DCN Nova services.

In addition the [following](https://github.com/fultonj/ussuri/blob/26880d84f788b70a395066bbdf3a2b9878436b33/glance/multiple_ceph/glance_multiple_ceph.yml#L48-L50)
parameters do the following extra configuration provided the
undercloud is hosting [patched glance containers](patch_glance/).

1. if `import_multi_stores` is true configure feature [import-multi-stores](https://review.opendev.org/#/c/667132)
2. if `copy_existing_image` is true configure feature [copy-existing-image](https://review.opendev.org/#/c/696457)
3. if `force_container` is true download a glance container patched
  with reviews from 1 xor 2 and forcibly replace the running glance
  container with it.

The `force_container` flag is used if you [patch](patch_glance/) 
the glance container image after deploying the overcloud and want
to quickly test it without redeploying. It's not necessary if you
patched the container before deploying.

## Did it work?

This can be tested with [validate](validate).

### Does glance see multiple stores?

Ensure the `control-planerc` is on the controller node and after
sourcing it, verify glance can see all three backends (the playbook
does this too).

If something wasn't configured corectly (e.g. the rbd client couldn't
authenticate with the ceph keyring), then glance would have refused 
to restart and display its list of available hosts.

```
(control-plane) [heat-admin@control-plane-controller-0 ~]$ glance stores-info
+----------+----------------------------------------------------------------------------------+
| Property | Value                                                                            |
+----------+----------------------------------------------------------------------------------+
| stores   | [{"id": "dcn1", "description": "dcn1 RBD backend"}, {"default": "true", "id":    |
|          | "central", "description": "central RBD backend"}, {"id": "dcn0", "description":  |
|          | "dcn0 RBD backend"}]                                                             |
+----------+----------------------------------------------------------------------------------+
(control-plane) [heat-admin@control-plane-controller-0 ~]$ 
```
### Can I import an image into more than one store?

Yes, run [use-multistore-glance.sh](validate/use-multistore-glance.sh).
The example output is at: http://paste.openstack.org/show/787129/

If you then boot an instance in the dcn0 AZ, you can observe it used 
the parent image which is local for fast COW boots.

- glance image at dcn0:
```
[root@dcn0-distributedcomputehci-0 nova]# podman exec ceph-mon-`hostname` rbd -p images ls -l --cluster dcn0
warning: line 36: 'osd_memory_target' in section 'osd' redefined 
NAME                                      SIZE   PARENT FMT PROT LOCK 
35cb2a43-eb89-4bed-99a2-c4376133a492      39 MiB          2           
35cb2a43-eb89-4bed-99a2-c4376133a492@snap 39 MiB          2 yes       
[root@dcn0-distributedcomputehci-0 nova]# 
```

- instance at dcn0 using parent glance image:
```
[root@dcn0-distributedcomputehci-0 nova]# podman exec ceph-mon-`hostname` rbd -p vms ls -l --cluster dcn0
warning: line 36: 'osd_memory_target' in section 'osd' redefined 
NAME                                      SIZE  PARENT                                           FMT PROT LOCK 
2b431c77-93b8-4edf-88d9-1fd518d987c2_disk 1 GiB images/35cb2a43-eb89-4bed-99a2-c4376133a492@snap   2      excl 
[root@dcn0-distributedcomputehci-0 nova]# 
```

Observe also in `/var/log/containers/glance/api.log` on the DCN node
that the query from local Nova to get the image was sent to the DCN
node's local Glance and not the central Glance.

## Next

- Implement [multiceph](../multiceph) so that
  [make_client](ansible/tasks/make_client.yml) and
  [install_client](ansible/tasks/install_client.yml)
  are not necessary.
- Use new
  [HAProxyEdge and GlanceApiEdge](https://review.opendev.org/#/c/699880)
  services in [dcn0 deployment](glance/dcn0/deploy.sh).
- Write TripleO glance patches to make this deployment possible
  without the extra tasks in [ansible](ansible) directory.
