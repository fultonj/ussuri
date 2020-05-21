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
(by this I mean 'openstack overcloud deploy' results in the the
overcloud having the required paramters because the deployment plan
was updated because the new Ansible roles did the right thing).
Once I'm confident of those interfaces working, I'll cycle back to
writing an Ansible module to do the actual derivation.

With respect those interfaces are working, a crucial step is that
Ansible gets the deployment plan updated. In other words if you run
the following after the playbook has run:

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
I replaced it with my own version from my own HCI deployment. To do
this, I got [mock_params](trim/mock_params) by modifying
[cli-derive-parameters.yaml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/playbooks/cli-derive-parameters.yaml@37) to
add a temporary task to save the result:

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
When I use the new mock_params molecule doesn't fail.

I then wrote [trim.py](trim/trim.py) to reduce the size of the 
original [mock_params](trim/mock_params) by 70% to get a new
[mock_params](mock_params).

## mock_roles

Updated cloudnull's [mock_roles](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/molecule/mock_roles)
to use Controller and ComputeHCI as that's a role combination you
would derive HCI paramters for.

## mocking ironic data

The ironic data comes from a call to [tripleo_get_introspected_data](https://github.com/openstack/tripleo-ansible/blob/master/tripleo_ansible/ansible_plugins/modules/tripleo_get_introspected_data.py) from within [the role's main tasks](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/tasks/main.yml@158).
which [merged](https://review.opendev.org/#/c/719462).

When converge runs the report [~/zuul-output/logs/reports.html](derive_zuul_report.html)
it shows that these tasks are skipped because the "Node block" is not
entered when `tripleo_all_nodes` is defined and it's hard coded to
an empty list in [converge.yml line 32](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/molecule/default/converge.yml@32).
I need to update it so that this data is mocked and I will get the 
mock data from my real deployment.

Similar move as before. On my real deployment:

```
    - name: Set all nodes fact
      set_fact:
        tripleo_all_nodes: "{{ known_available_nodes.baremetal_nodes | union(known_active_nodes.baremetal_nodes) }}"

- name: temp same tripleo_all_nodes
  copy: content="{{ tripleo_all_nodes }}" dest=/tmp/ironic
```

Run the deployment once, copy it in with this and delete it:
```
cp /tmp/ironic ironic.json
json2yaml ironic.json > mock_ironic_all
```

Then have converge pull in mock_ironic

```
        tripleo_all_nodes: "{{ lookup('file', '../mock_ironic_all') | from_yaml }}"
```

The next thing I need to do is mock in not the overview of all
introspected nodes (mock_ironic_all), but the actual introspection
data of two example nodes. I was able to extract it for one of my 
controllers and one of my ceph/computes this way:

```
    - name: Get baremetal inspection data for CephNode for John
      tripleo_get_introspected_data:
        node_id: 'bd776e75-7476-4287-9289-0403fb7958e4'
      register: johns_baremetal_data

    - name: write johns_data
      copy: content="{{ johns_baremetal_data }}" dest="/tmp/oc0-ceph-0.json"
```

I then created [mock_baremetal_ComputeHCI](mock_baremetal_ComputeHCI)
from the above (similar yaml conversion) and did something similar for 
[mock_baremetal_Controller](mock_baremetal_Controller). Finally, I
updated the loop in converge to set a value for one or the other.

I expect the real workflow to extract that stuff by UUID but since
the molecule test has no swift container full of introspection data
I'm going to set a variable and then just update the playbook with
some benign checks to only get those values from Ironic if they are
not defined. 

Here is my current approach:
```
- name: Converge
  hosts: all
  vars:
    tripleo_get_flatten_params: "{{ lookup('file', '../mock_params') | from_yaml }}"
    tripleo_role_list: "{{ lookup('file', '../mock_roles') | from_yaml }}"
    tripleo_all_nodes: "{{ lookup('file', '../mock_ironic_all') | from_yaml }}"
  tasks:
    - name: Derive params for each role
      include_role:
        name: tripleo_derived_parameters
      vars:
        tripleo_plan_name: "overcloud"
        tripleo_role_name: "{{ outer_item }}"
        tripleo_environment_parameters: "{{ tripleo_get_flatten_params.stack_data.environment_parameters }}"
        tripleo_heat_resource_tree: "{{ tripleo_get_flatten_params.stack_data.heat_resource_tree }}"
        baremetal_data: "{{ lookup('file', '../mock_baremetal_{{ outer_item }}') | from_yaml }}"
      loop: "{{ tripleo_role_list.roles }}"
      loop_control:
        loop_var: outer_item
```

## playbook_parameters

As seen in
[plan-environment-derived-params.yaml](https://review.opendev.org/#/c/714217/2/plan-samples/plan-environment-derived-params.yaml),
the following are passed to the deployment.

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

In a real deployment a modification of
[tasks/main.yml](https://review.opendev.org/#/c/719466/24/tripleo_ansible/roles/tripleo_derived_parameters/tasks/main.yml)
to add this:

```
    - fail:
        msg: "magic: {{ hci_profile_config }}"
```
Results in something like this:
```
TASK [tripleo_derived_parameters : fail] ***************************************
task path: /usr/share/ansible/roles/tripleo_derived_parameters/tasks/main.yml:171
Tuesday 19 May 2020  19:14:29 +0000 (0:00:00.112)       0:00:16.137   ***********
fatal: [localhost]: FAILED! => changed=false
msg: 'magic: {
  ''default'':
        {''average_guest_memory_size_in_mb'': 2048,
         ''average_guest_cpu_utilization_percentage'': 50}, 
  ''many_small_vms'':
        {''average_guest_memory_size_in_mb'': 1024,
         ''average_guest_cpu_utilization_percentage'': 20},
  ''few_large_vms'':
        {''average_guest_memory_size_in_mb'': 4096,
          ''average_guest_cpu_utilization_percentage'': 80},
  ''nfv_default'':
        {''average_guest_memory_size_in_mb'': 8192,
          ''average_guest_cpu_utilization_percentage'': 90}
  }'
```

To update [converge.yml](https://review.opendev.org/#/c/719466/24/tripleo_ansible/roles/tripleo_derived_parameters/molecule/default/converge.yml)
so that [tasks/main.yml](https://review.opendev.org/#/c/719466/24/tripleo_ansible/roles/tripleo_derived_parameters/tasks/main.yml)
can use variables like "{{ hci_profile_config }}", we 
create [mock_hci_profile_config](mock_hci_profile_config)
and mock it in like this:

```
- name: Converge
  hosts: all
  vars:
    tripleo_get_flatten_params: "{{ lookup('file', '../mock_params') | from_yaml }}"
    tripleo_role_list: "{{ lookup('file', '../mock_roles') | from_yaml }}"
    tripleo_all_nodes: "{{ lookup('file', '../mock_ironic_all') | from_yaml }}"
    hci_profile_config: "{{ lookup('file', '../mock_hci_profile_config') | from_yaml }}"
    hci_profile: default
    num_phy_cores_per_numa_node_for_pmd: 1
    hw_data_required: true
```

We are then able to fail the same way and dump the contents of the
varaible from molecule:

```
fatal: [centos8]: FAILED! => changed=false 
  msg: 'magic: {''default'': {''average_guest_memory_size_in_mb'': 
  2048, ''average_guest_cpu_utilization_percentage'': 50}, 
  ''many_small_vms'': {''average_guest_memory_size_in_mb'': 1024, 
  ''average_guest_cpu_utilization_percentage'': 20}, 
  ''few_large_vms'': {''average_guest_memory_size_in_mb'': 4096, 
  ''average_guest_cpu_utilization_percentage'': 80}, 
  ''nfv_default'': {''average_guest_memory_size_in_mb'': 8192, 
  ''average_guest_cpu_utilization_percentage'': 90}}'
ERROR: 
---- generated html file: file:///home/stack/zuul-output/logs/reports.html -----
=========================== short test summary info ============================
FAILED ../../../tests/test_molecule.py::test_molecule - AssertionError: asser...
======================== 1 failed in 102.02s (0:01:42) =========================
```
