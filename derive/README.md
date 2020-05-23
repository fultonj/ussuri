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
- Use [ironic.sh](ironic.sh) to tag two nodes for the deployment
- Use [deploy.sh](deploy.sh) to deploy the two nodes
- Edit [overrides.yaml](overrides.yaml) as you see fit

Prior to running [deploy.sh](deploy.sh) you'll need to update your
environment [tripleo-heat-templates patch](https://review.opendev.org/#/c/714217)
patch is used.

If you're testing on a real deployment, then I
have [my own version](roles-tripleo_derived_parameters-tasks.yml)
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

- `cd tripleo-ansible`
- `time ./scripts/run-local-test tripleo_derived_parameters`

This will trigger molecule and it takes about 5 minutes on my 
undercloud. Look at the generated 


The molecule run takes about 4 minutes on my undercloud and doesn't
fail. Look at the genereated HTML to understnd what happened within
the container. Here's my shortcut to pull it to my laptop:

```
 ssh -A hamfast -t ssh -A stack@undercloud "cat /home/stack/zuul-output/logs/reports.html" > derive_zuul_report_kerenl.html
```

## How do I mock data with Molecule

See [data](data).

# Next Steps

As per the [mailing list](http://lists.openstack.org/pipermail/openstack-discuss/2020-May/015014.html) write a new ansible module and call it. I'll [link a patch](https://github.com/openstack/tripleo-validations/commit/70596306b19809da8429486df6d39d1d03cf456f) from the last time I wrote a new module.
