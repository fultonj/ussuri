# Derived Paramters Development

[Ansible is replacing Mistral in TripleO](https://specs.openstack.org/openstack/tripleo-specs/specs/ussuri/mistral-to-ansible.html)
so the 
[deriving TripleO parameters feature](https://specs.openstack.org/openstack/tripleo-specs/specs/pike/tripleo-derive-parameters.html) 
needs to be updated. [cloudnull](https://github.com/cloudnull) has provided
[a way](http://lists.openstack.org/pipermail/openstack-discuss/2020-March/013476.html) 
to have `openstack overcloud deploy` trigger the necessary Ansible
to update the deployment plan so I just need to write an Ansible
module to derive the HCI parameters based on my 
[original prototype](https://github.com/fultonj/derived-tht-poc).

This will only apply to Ussuri, Victoria and newer. Downstream that
might be OSP17. Train/OSP16 and Queens/OSP13 will continue to use
Mistral. Either way the user experience should be similar to what's
[already documented](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html-single/hyper-converged_infrastructure_guide/index#resource-isolation-cpu-ram).

This directory has scripts I use to set up my environment to use the
[existing patches](https://review.opendev.org/#/q/derived+topic:mistral_to_ansible)
and do enough of a deployment with the proposed changes so see the
deployment plan getting updated the way it would if Mistrtal had done
it. 

## How to run it on an undercloud in the context of a real deployment

- Use [tripleo-heat-templates patch](https://review.opendev.org/#/c/714217) `git review -d 714217`
- Use [tripleo-ansible patch](https://review.opendev.org/#/c/719466) `git review -d 719466`

- Use [ironic.sh](ironic.sh) to tag two nodes for the deployment
- Use [deploy.sh](deploy.sh) to deploy the two nodes
- Edit [overrides.yaml](overrides.yaml) as you see fit

Prior to running [deploy.sh](deploy.sh) you'll need to update your
environment so the 
[tripleo-ansible patch](https://review.opendev.org/#/c/719466)
and 
[tripleo-heat-templates patch](https://review.opendev.org/#/c/714217)
patches are used.

I have [my own version](roles-tripleo_derived_parameters-tasks.yml)
of [roles/tripleo_derived_parameters/tasks/main.yml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/tasks/main.yml)
which takes some paramters that the HCI derive paramter ansible module
would return as output called `derived_parameters_result` and then
lets the workflow update the depoyment plan as usual but with that
result. My version then downloads the `plan-environment.yaml` from
Swift and shows if it contains the result. It then fails the
deployment early. I can see that all the right things are happening 
so this should give me a foundation to develop my Ansible module on
top of.

## How to run it on an undercloud with molecule

- Get [tripleo-ansible patch](https://review.opendev.org/#/c/719466) `git review -d 719466`
- `cd tripleo-ansible`
- `time ./scripts/run-local-test tripleo_derived_parameters`

The molecule run takes about 6 minutes on my undercloud and doesn't
fail. I should probably find a way to update 
[tripleo_derived_parameters/molecule/default/verify.yml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/molecule/default/verify.yml)
so I can see it doing something.

I might have it do something similar to what my own 
[my own version](roles-tripleo_derived_parameters-tasks.yml)
of [roles/tripleo_derived_parameters/tasks/main.yml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/tasks/main.yml)
does.

# Next Steps

- Confirm I can see the molecule test update a representation of the deployment plan
- Trim [mock_params](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/molecule/mock_params) so it isn't so needlessly large
- Stack a new submission on top of [tripleo-ansible patch](https://review.opendev.org/#/c/719466) which introduces a new ansible module to derive parameters for HCI ([I have not written an ansible module since Nov 2019](https://github.com/openstack/tripleo-validations/commit/70596306b19809da8429486df6d39d1d03cf456f))
