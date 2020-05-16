## Mocking input data for derived parameters role

We have a role that derives the parameters and updates the deployment
plan correctly. 

If you run:

```
 openstack overcloud deploy --templates 
 -r ~/roles_for_hci.yaml \
 -p ~/templates/plan-samples/plan-environment-derived-params.yaml \
 -e ~/templates/environments/ceph-ansible/ceph-ansible.yaml \
 ...
```

Then your overcloud will have the right cpu allocation ratio and
reserved memory. The crucial step is that Ansible gets the deployment
plan updated. In other words if you run the following:

```
swift download overcloud plan-environment.yaml --output /tmp/plan-environment.yaml
grep derived -A 10 /tmp/plan-environment.yaml
```

Then you'll see something like this which is sufficient to make the
rest of the overcloud deployment do the right thing:

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
is passed. This playbook calls the following role like this:

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

If it's passed the right stuff via the vars above, then it will do
it's job. We can then isolate the deployment of the derive parameters 
modules by having molecule call the above roles as seen in the
molecule [converge.yml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/molecule/default/converge.yml)
section of the new role.

```
  vars:
    tripleo_get_flatten_params: "{{ lookup('file', '../mock_params') | from_yaml }}"
    tripleo_role_list: "{{ lookup('file', '../mock_roles') | from_yaml }}"
```

The `tripleo_get_flatten_stack` task in [cli-derive-parameters.yaml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/playbooks/cli-derive-parameters.yaml@37)
gets the input paramters from a TripleO deployment.

I have cloudnull's original [mock_params](https://review.opendev.org/#/c/719466/22/tripleo_ansible/roles/tripleo_derived_parameters/molecule/mock_params)
but it doesn't contain anything I would HCI parameters for so I'm 
going to replace it with my own version.

I got [tripleo_get_flatten_params.yaml](tripleo_get_flatten_params.yaml)
By modifying [cli-derive-parameters.yaml](https://review.opendev.org/#/c/719466/22/tripleo_ansible/playbooks/cli-derive-parameters.yaml@37)
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
json2yaml /tmp/tripleo_get_flatten_params.json > tripleo_get_flatten_params.yaml
```

When I use tripleo_get_flatten_params.yaml in place of mock_params 
molecule doesn't fail.

I now need to add more parameters as input in converge to exercise the
new role with molecule.


