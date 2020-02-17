# Apply upstream patchs to glance-api container image

This describes how to apply the following patch to the glance-api
container deployed by TripleO.

- import-multi-stores: https://review.opendev.org/#/c/667132

## TL;DR

Before deployment run 
[glance-container-patch.sh](glance-container-patch.sh)
like this:

```
bash glance-container-patch.sh
```

Then later when TripleO deploys the overcloud, the glance service will 
be running with the desired patch. You can then use TripleO patches
like this to configure the new feature:

- https://review.opendev.org/#/c/704373
- https://review.opendev.org/#/c/704374

## Details

### import-multi-stores

To test [import-multi-stores](https://review.opendev.org/#/c/667132)
both configuration changes and container changes are required.

#### Configuration Changes

Add the following in glance-api.conf:

`enabled_import_methods = ['glance-direct', 'web-download']`

The following confirms it is not yet enabled:

```
(undercloud) [stack@undercloud ~]$ sudo grep enabled_import_methods /var/lib/config-data/puppet-generated/glance_api/etc/glance/glance-api.conf | grep -v \#
enabled_import_methods=[web-download]
(undercloud) [stack@undercloud ~]$ 
```

#### Container Changes

Use the [glance-container-patch.sh](glance-container-patch.sh) script
as below which uses TripleO's 
[container image preparation](https://docs.openstack.org/project-deploy-guide/tripleo-docs/latest/deployment/container_image_prepare.html#modify-with-python-source-code-installed-via-pip-from-opendev-gerrit).

```
bash glance-container-patch.sh import
```

The above prepares your undercloud to deploy a patched version of the
glance-api image when the overcloud is deployed.

### copy-existing-image

To test [copy-existing-image](https://review.opendev.org/#/c/696457)
both configuration changes and container changes are required.

#### Configuration Changes

Add the following in glance-api.conf:

`enabled_import_methods = ['glance-direct', 'web-download', 'copy-image']`

The following confirms it is not yet enabled:

```
(undercloud) [stack@undercloud ~]$ sudo grep enabled_import_methods /var/lib/config-data/puppet-generated/glance_api/etc/glance/glance-api.conf | grep -v \#
enabled_import_methods=[web-download]
(undercloud) [stack@undercloud ~]$ 
```

Add the following to entry_points.txt:

`copy_image = glance.async_.flows._internal_plugins.copy_image:get_flow`

As per [this example](https://review.opendev.org/#/c/696457/1/setup.cfg), the following confirms that the above has not yet been applied:

```
[root@control-plane-controller-0 ~]# podman exec -ti glance_api cat /usr/lib/python2.7/site-packages/glance-19.1.0.dev11-py2.7.egg-info/entry_points.txt | grep glance.image_import.internal_plugins -A 2
[glance.image_import.internal_plugins]
web_download = glance.async_.flows._internal_plugins.web_download:get_flow

[root@control-plane-controller-0 ~]# 
```

(Todo: determine if tripleo-modify-image applies the above via the setup.cfg)

Beacuse TripleO does not yet support the above configuration, both of
the above can be applied with Ansible after the overcloud is deployed
as a workaround. If you run the play [multiple_ceph](../multiple_ceph)

#### Container Changes

Use the [glance-container-patch.sh](glance-container-patch.sh) script
as below which uses TripleO's 
[container image preparation](https://docs.openstack.org/project-deploy-guide/tripleo-docs/latest/deployment/container_image_prepare.html#modify-with-python-source-code-installed-via-pip-from-opendev-gerrit).

```
bash glance-container-patch.sh copy
```

The above prepares your undercloud to deploy a patched version of the
glance-api image when the overcloud is deployed. 
