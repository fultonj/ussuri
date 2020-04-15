# Derived Paramters Development

[Mistral is replacing Ansible in TripleO](https://specs.openstack.org/openstack/tripleo-specs/specs/ussuri/mistral-to-ansible.html)
so the 
[deriving TripleO parameters feature](https://specs.openstack.org/openstack/tripleo-specs/specs/pike/tripleo-derive-parameters.html) 
needs to be updated. [cloudnull](https://github.com/cloudnull) has provided
[a way](http://lists.openstack.org/pipermail/openstack-discuss/2020-March/013476.html) 
to have `openstack overcloud deploy` trigger the necessary Ansible
to update the deployment plan so I just need to write an Ansible
module to derive the HCI parameters based on my 
[original prototype](https://github.com/fultonj/derived-tht-poc).

This will only apply to Ussuri, Victoria and newer. Downstream that
will be OSP17. Train/OSP16 and Queens/OSP13 will continue to use
Mistral. Either way the user experience should be similar to what's
[already documented](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html-single/hyper-converged_infrastructure_guide/index#resource-isolation-cpu-ram).

This directory has scripts I use to set up my environment to use the
[existing patches](https://review.opendev.org/#/q/derived+topic:mistral_to_ansible)
and do enough of a deployment to the necessary changes landing in the
deployment plan the way the Mistrtal changes did.

## What do you get

An overcloud deployed with network isolation containing:

- 1 Controller
- 1 ComputeHCI

## How to do it

- Use [ironic.sh](ironic.sh) to tag two nodes for the deployment
- Use [deploy.sh](deploy.sh) to deploy the two nodes
- Edit [overrides.yaml](overrides.yaml) as you see fit

To be continued...
