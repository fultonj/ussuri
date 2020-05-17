## Mocking input data for derived parameters Ansible role

We have a new Ansible role called `tripleo_derived_parameters` 
(see [tasks/main.yml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/tasks/main.yml))
which derives the parameters and updates the deployment plan correctly.

If you run:

```
 openstack overcloud deploy --templates 
 -r ~/roles_for_hci.yaml \
 -p ~/templates/plan-samples/plan-environment-derived-params.yaml \
 -e ~/templates/environments/ceph-ansible/ceph-ansible.yaml \
 ...
```

With the new [plan-environment-derived-params.yaml](https://review.opendev.org/#/c/714217/2/plan-samples/plan-environment-derived-params.yaml), 
then your overcloud will have the CPU allocation ratio and
reserved memory as computed by Ansible (without Mistral).
For now I'm faking the computation by setting the variables 
directly so I can make sure all the interfaces are working
and then I'll cycle back to writing an Ansible module to do
the actual derivation.

With respect to get all the interfaces are working, a crucial step
is that Ansible gets the deployment plan updated. In other words if
you run the following after the playbook has run:

```
swift download overcloud plan-environment.yaml --output /tmp/plan-environment.yaml
grep derived -A 10 /tmp/plan-environment.yaml
```

then you'll see something like this which is sufficient to make the
rest of the overcloud deployment do the right thing
(`derived_parameters` in THT [behaves similarly](https://opendev.org/openstack/tripleo-common/src/branch/stable/queens/tripleo_common/actions/templates.py#L400-L403)
to `parameter_defaults`).

```
derived_parameters:
  ComputeHCIExtraConfig:
    nova::cpu_allocation_ratio: 1.5
  ComputeHCIParameters:
    NovaReservedHostMemory: 14336
  HciCephAllExtraConfig:
    nova::cpu_allocation_ratio: 1.5
  HciCephAllParameters:
    NovaReservedHostMemory: 14336
```

In order to get the above roles updated, the playbook [cli-derive-parameters.yaml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/playbooks/cli-derive-parameters.yaml@37)
is run whenver `-p ~/templates/plan-samples/plan-environment-derived-params.yaml`
is passed. This playbook calls the new role like this:

```
- name: Derive params for each role
  include_role:
    name: tripleo_derived_parameters
  vars:
    tripleo_plan_name: "{{ plan }}"
    tripleo_role_name: "{{ outer_item }}"
    tripleo_environment_parameters: "{{ tripleo_get_flatten_params.stack_data.environment_parameters }}"
    tripleo_heat_resource_tree: "{{ tripleo_get_flatten_params.stack_data.heat_resource_tree }}"
```

If it's passed the appropriate inputs via the vars above, then it will
do its job. We can then simplify the development of the derive
parameters modules by having molecule call the above roles as seen in
the molecule [converge.yml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/molecule/default/converge.yml)
section of the new role and mocking the real data like this:

```
vars:
  tripleo_get_flatten_params: "{{ lookup('file', '../mock_params') | from_yaml }}"
  tripleo_role_list: "{{ lookup('file', '../mock_roles') | from_yaml }}"
```

Let's look at the parameters we need to mock more closely in the next
sections.

## mock_params

The `tripleo_get_flatten_stack` task in [cli-derive-parameters.yaml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/playbooks/cli-derive-parameters.yaml@37)
gets the input paramters from a TripleO deployment.

I have cloudnull's original [mock_params](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/molecule/mock_params)
but it doesn't contain anything I would derive HCI parameters for so
I'm  going to replace it with my own version from my own HCI deployment
and then I'm going to trim it as it's much longer than it needs to be
at about over 12,000 lines, or 500K.

I got [mock_params](mock_params) by modifying [cli-derive-parameters.yaml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/playbooks/cli-derive-parameters.yaml@37)
to add a temporary task to save the result:

```
- name: Get flatten params
  tripleo_get_flatten_stack:
    container: "{{ plan }}"
  register: tripleo_get_flatten_params
  when:
    - tripleo_get_flatten_params is undefined

- name: temp save tripleo_get_flatten_params
  copy: content="{{ tripleo_get_flatten_params }}" dest=/tmp/tripleo_get_flatten_params.json
```
I then did a quick conversion:
```
sudo yum install -y npm
sudo npm install -g json2yaml
json2yaml /tmp/tripleo_get_flatten_params.json > mock_params 
```
When I use the new mock_params molecule doesn't fail. I will trim it later.

I now need to add more parameters as input in the converge playbook to
exercise the new role with molecule.

## mock_roles

Updated cloudnull's [mock_roles](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/molecule/mock_roles)
to use Controller and ComputeHCI as that's a role combination you
would derive HCI paramters for.

## ironic_data

The ironic data comes from a call to [tripleo_get_introspected_data](https://github.com/openstack/tripleo-ansible/blob/master/tripleo_ansible/ansible_plugins/modules/tripleo_get_introspected_data.py) from within [the role's main tasks](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/tasks/main.yml@158).
which [merged](https://review.opendev.org/#/c/719462).

We'll need to mock this data into molecule. At the moment when I run
the job in molecule and 
examine [~/zuul-output/logs/reports.html](derive_zuul_report.html),
I see that after "set role feature fact" is executed the "Node block"
is skipped and I assume that's because `tripleo_all_nodes` is defined.

## playbook_parameters

As seen in
[plan-environment-derived-params.yaml](https://review.opendev.org/#/c/714217/2/plan-samples/plan-environment-derived-params.yaml),
the following are passed so I'll need hci_* variables.

```
playbook_parameters:
  cli-derive-parameters.yaml:
    hw_data_required: true
    num_phy_cores_per_numa_node_for_pmd: 1
    huge_page_allocation_percentage: 50
    hci_profile: default
    hci_profile_config:
      default:
        average_guest_memory_size_in_mb: 2048
        average_guest_cpu_utilization_percentage: 50
```
