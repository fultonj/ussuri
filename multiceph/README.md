# Environment to develop multiple-external-ceph

This directory of scripts allows me to develop the blueprint
[multiple-external-ceph](https://blueprints.launchpad.net/tripleo/+spec/multiple-external-ceph).

## Deployment

- Prerequisite: two centos7 servers (accessible via ssh stack@cent{0,1})
- From host which can ssh to cent{0,1} create ceph clusters with [ceph/deploy.sh](ceph/deploy.sh)
- From undercloud provided by tripleo-lab:
  - ensure you have patches from [multiceph](https://review.opendev.org/#/q/topic:bp/multiple-external-ceph+(status:open+OR+status:merged))
  - run [deploy.sh](deploy.sh) and then [validate.sh](validate.sh)

## Usecases

### Architecture

- ceph0: external ceph cluster offering ceph service on 192.168.24.250
- ceph1: external ceph cluster offering ceph service on 192.168.24.251
- undercloud: tripleo-lab undercloud
- controller0: tripleo-lab controller
- compute0: tripleo-lab compute
- ceph0-storage0: tripleo-lab ceph-storage

### Usecase 1: Two External

tripleo deploys an overcloud which uses two external ceph
clusters.

Success criteria:
1. controller0 has the following files:
   - /etc/ceph/ceph0.conf
   - /etc/ceph/ceph1.conf
   - /etc/ceph/ceph0.client.openstack.keyring
   - /etc/ceph/ceph1.client.openstack.keyring
2. controller0 can use RBD to RW to pools on ceph0 and ceph1

**Status** [verified](https://github.com/fultonj/ussuri/commit/fc288b7dd3f7af125598956ade75dcfd15cbc309)

### Usecase 2: One Internal and One External

tripleo deploys an overcloud with its own internal ceph
cluster but is also configured to use one or more external ceph
clusters.

Success criteria:
1. controller0 has the following files:
   - /etc/ceph/ceph.conf
   - /etc/ceph/ceph1.conf
   - /etc/ceph/ceph.client.openstack.keyring
   - /etc/ceph/ceph1.client.openstack.keyring
2. controller0 can use RBD to RW to pools on the internal ceph
   cluster and the external ceph cluster on ceph0

**Status** [verified]

### Usecase 3: Apply the feature to a DCN deployment

1. Deploy central with an extra key for edge to access it

Use [CephExtraKeys](https://review.opendev.org/#/c/700947) to deploy
an internal ceph cluster at a central site with an additional key
which may be used only to RW to the glance images pool like the
following:

```
  CephExtraKeys:
    - name: "client.glance.edge"
      caps:
        mgr: "allow *"
        mon: "profile rbd"
        osd: "profile rbd pool=images"
      key: "AQBRgQ9eAAAAABAAv84zEilJYZPNu00000Edge=="
      mode: "0600"
```

2. Deploy DCN to use the extra key from central and make an extra key
   for central to access it

Deploy a second internal ceph cluster at a DCN site which uses the
following `CephExtraKeys` parameter to deploy an additional key
which may be used only to RW to the DCN ceph glance images pool:

```
  CephExtraKeys:
    - name: "client.glance.central"
      caps:
        mgr: "allow *"
        mon: "profile rbd"
        osd: "profile rbd pool=images"
      key: "AQBRgQ9eAAAAABAAv84zEilJYZPNu00Central=="
      mode: "0600"
```

The same DCN deployment should use the multiple-external-ceph
feature so that Usecase 2 is also tested and as a result access
to an external ceph cluster is also configured using the
`client.glance.edge` keyring created when central was deployed.

3. Update central to use the DCN cluster with the extra edge key

Run a stack update on the central deployment and use the
multiple-external-ceph feature so Usecase 2 is also tested
and as a result, access to the external ceph cluster at the
DCN site is also configured using the `client.glance.central`
keyring.

The third usecase should be demonstrated by modifying
the [glance](../glance) usecase.

**Status** to do
