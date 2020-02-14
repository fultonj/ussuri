# Cheat Sheet

Manual commands that evolved into the glance_multiple_ceph.yml playbook

## Configure Additional Ceph Clients

### Create keyring on dcnN

- Create
`podman exec ceph-mon-$(hostname) ceph --conf /etc/ceph/dcn0.conf auth get-or-create client.dcn0.glance mon 'profile rbd' osd 'profile rbd pool=images'`

- Export
`podman exec ceph-mon-$(hostname) ceph --conf /etc/ceph/dcn0.conf auth get client.dcn0.glance > client.dcn0.glance.keyring`

- Move `dcn0.conf` and `client.dcn0.glance.keyring` to `/etc/ceph` on central

### Use keyring on central

- Use the keying to write

`podman exec ceph-mon-$(hostname) rbd --id dcn0.glance --keyring /etc/ceph/client.dcn0.glance.keyring --conf /etc/ceph/dcn0.conf create --size 1024 images/from_central`

- Use the keying to read

`podman exec ceph-mon-$(hostname) rbd --id dcn0.glance --keyring /etc/ceph/client.dcn0.glance.keyring --conf /etc/ceph/dcn0.conf ls images`

- Modify the ceph conf client section for the benefit of the glance
  client
  
E.g. ensure the following lines are in /etc/ceph/dcn0.conf

```
[client]
keyring = /etc/ceph/client.dcn0.glance.keyring
```

## Configure Additional Glance Backends

### From Container Host

The following assumes you have scp'd the control-plancerc to the controller.

Query backends that glance knows about and verify glance is able to
see an image previously uploaded.

```
source /home/heat-admin/control-planerc
glance image-list
glance stores-info
```

Restart glance_api container to check it can see newly installed Ceph
client files:

```
sudo podman exec glance_api ls /etc/ceph/
sudo systemctl restart tripleo_glance_api.service
sudo podman exec glance_api ls /etc/ceph/
```

See the running glance configuration:

```
sudo podman exec glance_api ps axu
sudo podman exec glance_api cat /etc/glance/glance-api.conf | grep -v \# | egrep -v "^$"
```

Then add variations as needed, e.g. to see the [default storage identifier](https://docs.openstack.org/glance/latest/configuration/glance_api.html#glance-store) add the following to the end of the last line above:

` | fgrep '[glance_store]' -A 7`

To manually (only for experimental purposes) modify the running glance
container config:

```
sudo vi /var/lib/config-data/puppet-generated/glance_api/etc/glance/glance-api.conf
sudo systemctl restart tripleo_glance_api.service
```

### Modify config file in running container

```
# add "enabled_backends = central:rbd, dcn0:rbd" to DEFAULT
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf DEFAULT enabled_backends central:rbd,dcn0:rbd

# add new "[central]" section
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf central

# add to "stores=http,rbd" to "[central]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf central stores http,rbd

# add to "default_store=rbd" to "[central]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf central default_store rbd

# add to "rbd_store_pool=images" to "[central]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf central rbd_store_pool images

# add to "rbd_store_user=openstack" to "[central]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf central rbd_store_user openstack

# add to "rbd_store_ceph_conf=/etc/ceph/ceph.conf" to "[central]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf central rbd_store_ceph_conf /etc/ceph/ceph.conf

# add to "os_region_name=regionOne" to "[central]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf central os_region_name regionOne

# delete entire "[glance_store]" section
  sudo podman exec glance_api crudini --del /etc/glance/glance-api.conf glance_store

# add new "[glance_store]" section 
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf glance_store

# add "default_backend = central" to "[glance_store]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf glance_store default_backend central

# add new "[dcn0]" section
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf dcn0

# add "rbd_store_pool=images" to "[dcn0]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf dcn0 rbd_store_pool images

# add "rbd_store_user=dcn0.glance" to "[dcn0]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf dcn0 rbd_store_user dcn0.glance

# add "rbd_store_ceph_conf=/etc/ceph/dcn0.conf" to "[dcn0]"
  sudo podman exec glance_api crudini --set /etc/glance/glance-api.conf dcn0 rbd_store_ceph_conf /etc/ceph/dcn0.conf
```

