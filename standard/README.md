# Standard Deployment

## What do you get

An overcloud deployed with network isolation containing:

- 1 controller
- 1 compute
- 1 ceph-storage 

Increase each of the above to 3 by editing 
[overrides.yaml](overrides.yaml). More OSDs per ceph node 
are also available but this deploys more quickly.

## How to do it

Set flags in [deploy-config-download.sh](deploy-config-download.sh) to: 

- tag 3 of the 6 available ceph nodes as compute nodes
- create a heat stack (deploys virtual bare metal)
- download the configuration as ansible playbooks
- use ansible to configure the overcloud

Use [validate.sh](validate.sh) to transfer files to the controller
node and run a validation (this is only necessary since the undercloud
cannot reach the "external" network where the overcloud services
listen). The validation then:

- Reports on Ceph status
- Creates a Cinder volume (and shows it in ceph volumes pool)
- Creates a Glance image (and shows it in ceph images pool)
- Creates a private Neutron network
- Creates a Nova instance
