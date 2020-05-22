#!/usr/bin/python3

import re
import yaml

# Which file do you want to trim?
#FILE = 'mock_baremetal_ComputeHCI'
#FILE = 'mock_baremetal_Controller'
#FILE = 'mock_ironic_all'
FILE = 'mock_params'

# for any type of thing, how many should we have?
# warning, if trim_resources() hits limit, molecule will probably fail
# LIMIT = float("inf") # infinity, i.e. no limit
LIMIT = 241
# recommended value:
# 241 == len(file_as_dict['stack_data']['heat_resource_tree']['resources'])
# if you want you can have limit per data type but how much time do you spend?

save_yaml = True
save_json = False
unwanted_re = re.compile("^Container.*|.*ContainerImage$|.*Tempurl.*")
unwanted_list = [
    'MigrationSshKey',
    'PacemakerRemoteAuthkey',
    ]

def trim_params(params):
    new_params = {}
    i = 0
    for k, definition in params.items():
        i = i+1
        if i == LIMIT:
            print("reached limit")
            break
        if not unwanted_re.match(k) and k not in unwanted_list:
            if 'default' in definition:
                new_default = definition['default']
            else:
                new_default = definition
            # only want the default value; don't care about full definition
            new_params[k] = {'default': new_default}
    print(str(i) + " parameters")
    return new_params

def trim_resources(resources):
    new_resources = {}
    i = 0
    for k, resource in resources.items():
        i = i+1
        if i == LIMIT:
            print("WARNING: reached resources limit")
            break
        new_resource = {}
        if 'name' in resource:
            new_resource['name'] = resource['name']
        if 'id' in resource:
          new_resource['id'] = resource['id']
        if 'type' in resource:
          new_resource['type'] = resource['type']
        if 'description' in resource:
            pass # saving some space
        if 'parameter_groups' in resource:
            new_resource['parameter_groups'] = resource['parameter_groups']
        if 'resources' in resource:
            # only use the first item on the list to save space
            new_resource['resources'] = resource['resources'][:1]
        if 'parameters' in resource:
            # only use the first item on the list to save space
            new_resource['parameters'] = resource['parameters'][:1]
        new_resources[k] = new_resource
    print(str(i) + " resources")
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
    print("Trimming " + FILE)
    with open(FILE, 'r') as stream:
        try:
            file_as_dict = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    new_params = {}
    for k, v in file_as_dict.items():
        if FILE == 'mock_params':
            if k != 'stack_data':
                new_params[k] = v
            else:
                new_params[k] = trim_stack_data(v)
        elif FILE == 'mock_baremetal_ComputeHCI':
            print(FILE + " is not yet supported")
            exit(0)
        elif FILE == 'mock_baremetal_Controller':
            print(FILE + " is not yet supported")
            exit(0)
        elif FILE == 'mock_ironic_all':
            print(FILE + " is not yet supported")
            exit(0)

    if save_yaml:
        with open("../" + FILE, 'w') as file:
            yaml.dump(new_params, file)
    if save_json:
        import json
        with open(FILE + ".json", 'w') as file:
            json.dump(new_params, file)
