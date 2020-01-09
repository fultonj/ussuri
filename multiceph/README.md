# Environment to develop multiple-external-ceph

This directory of scripts allows me to develop the blueprint
[multiple-external-ceph](https://blueprints.launchpad.net/tripleo/+spec/multiple-external-ceph).

## Deployment

- Prerequisite: three centos7 servers (accessible via ssh stack@cent{0,1,2})
- From host which can ssh into cent{0,1}
  - Create external ceph clusters on cent{0,1} with [ceph/deploy.sh](ceph/deploy.sh)
- From cent2
  - Run [boostrap.sh](boostrap.sh)
  - todo: Run [deploy.sh](deploy.sh) with [basecase.yaml](basecase.yaml) on cent2

## Usecases

### Architecture

1. cent0: standalone ceph deployment
2. cent1: standalone ceph deployment
3. ceph2: [standalone](https://docs.openstack.org/project-deploy-guide/tripleo-docs/latest/deployment/standalone.html) tripleo deployment

### Usecase 1: Two External

tripleo-standalone deploys an overcloud which uses two external ceph
clusters.

Success criteria:
1. tripleo-standalone has the following files:
   - /etc/ceph/cent0.conf
   - /etc/ceph/cent1.conf
   - /etc/ceph/cent0.client.openstack.keyring
   - /etc/ceph/cent1.client.openstack.keyring
2. tripleo-standalone can use RBD to RW to pools on cent0 and cent1

### Usecase 2: One Internal and One External

tripleo-standalone deploys an overcloud with its own internal ceph
cluster but is also configured to use one or more external ceph
clusters.

Success criteria:
1. tripleo-standalone has the following files:
   - /etc/ceph/ceph.conf
   - /etc/ceph/cent0.conf
   - /etc/ceph/ceph.client.openstack.keyring
   - /etc/ceph/cent0.client.openstack.keyring
2. tripleo-standalone can use RBD to RW to pools on the internal ceph
   cluster and the external ceph cluster on cent0

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
