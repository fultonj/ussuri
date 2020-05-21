#!/usr/bin/python3

import yaml
import re

save_yaml = True
save_json = False
unwanted_re = re.compile("^Container.*|.*ContainerImage$|.*Tempurl.*")
unwanted_list = [
    'MigrationSshKey',
    'PacemakerRemoteAuthkey',
    ]

def trim_params(params):
    new_params = {}
    for k, definition in params.items():
        if not unwanted_re.match(k) and k not in unwanted_list:
            if 'default' in definition:
                new_default = definition['default']
            else:
                new_default = definition
            # only want the default value; don't care about full definition
            new_params[k] = {'default': new_default}
    return new_params

def trim_resources(resources):
    return resources
    # ended up not using the rest of this function...
    new_resources = {}
    for k, resource in resources.items():
        new_resource = {}
        if 'name' in resource:
            new_resource['name'] = resource['name']
        if 'id' in resource:
            new_resource['id'] = resource['id']
        if 'type' in resource:
            new_resource['type'] = resource['type']
        if 'description' in resource:
            new_resource['description'] = resource['description']
        if 'parameters' in resource:
            new_resource['parameters'] = resource['parameters']
        new_resources[k] = new_resource
    return new_resources

def trim_stack_data(stack_data):
    new_stack_data = {}
    for k, v in stack_data.items():
        if k == 'heat_resource_tree':
            # copy it in
            new_stack_data[k] = stack_data[k]
            # but set resources to an empty list
            new_stack_data[k]['resources'] = trim_resources(stack_data[k]['resources'])
            # and trim the parameters
            new_stack_data[k]['parameters'] = trim_params(stack_data[k]['parameters'])
        elif k == 'environment_parameters':
            # add new key
            new_stack_data.update({k: dict()})
            for param, value in stack_data[k].items():
                # only add values that are not unwanted
                if not unwanted_re.match(param):
                    new_stack_data[k][param] = value
    return new_stack_data

if __name__ == "__main__":
    with open("mock_params", 'r') as stream:
        try:
            mock_params = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    new_params = {}
    for k, v in mock_params.items():
        if k != 'stack_data':
            new_params[k] = v
        else:
            new_params[k] = trim_stack_data(v)

    if save_yaml:
        with open("../mock_params", 'w') as file:
            yaml.dump(new_params, file)
    if save_json:
        import json
        with open("mock_params.json", 'w') as file:
            json.dump(new_params, file)

