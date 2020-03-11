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

- Pull in missing [unmerged changes](unmerged)
- Tag nodes with [ironic.sh](ironic.sh)
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

- Use [use-multistore-glance.sh](use-multistore-glance.sh) to import
  an image into both `default_backend` and `dcn0`
  with [import-multi-stores](https://review.opendev.org/#/c/667132)
  and then copy that image to `dcn1`
  with [copy-existing-image](https://review.opendev.org/#/c/696457).

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

## Todo

- Modify templates to configure all three glance services with
  `enabled_import_methods = [glance-direct,web-download,copy-image]`
- Modify [ceph_keys.sh](ceph_keys.sh) such that:
  - `dcn0/dcn_ceph_keys.yaml` (from `ceph_keys.sh 2`) has:
    ```
      CephExternalMultiConfig:
        - cluster: "central"
      ...
      ceph_conf_overrides:
        client:
          keyring: /etc/ceph/central.client.glance.keyring
    ```
  - `control-plane/ceph_keys_update.yaml` (from `ceph_keys.sh 3`) has:
     ```
      CephExternalMultiConfig:
        - cluster: "dcn0"
          fsid: "0c10d6b5-a455-4c4d-bd53-8f2b9357c3c7"
          external_cluster_mon_ips: "172.16.11.45"
          keys:
            - name: "client.glance"
              caps:
                mgr: "allow *"
                mon: "profile rbd"
                osd: "profile rbd pool=images"
              key: "AQDY215eAAAAABAAv+R9oML+7c8FFygX7eUWrQ=="
              mode: "0600"
          dashboard_enabled: false
          ceph_conf_overrides:
            client:
              keyring: /etc/ceph/dcn0.client.glance.keyring
        - cluster: "dcn1"
          fsid: "8649d6c3-dcb3-4aae-8c19-8c2fe5a853ac"
          external_cluster_mon_ips: "172.16.11.246"
          keys:
            - name: "client.glance"
              caps:
                mgr: "allow *"
                mon: "profile rbd"
                osd: "profile rbd pool=images"
              key: "AQCSH19eAAAAABAAi1MVKfoJv5dcdWsQd4OG+Q=="
              mode: "0600"
          dashboard_enabled: false
          ceph_conf_overrides:
            client:
              keyring: /etc/ceph/dcn1.client.glance.keyring
      ```

The current templates work but only after the above two configurations
are added by hand.
