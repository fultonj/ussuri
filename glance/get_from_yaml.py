#!/usr/bin/env python

import argparse
import sys
import yaml

def parse_opts(argv):
    parser = argparse.ArgumentParser(
            description='Extracts a value from a YAML file given a key')
    parser.add_argument('-y', '--yaml-file', metavar='YAML_FILE',
                        nargs='+', help="Absolute path to the YAML file from "
                        "which the value of they key will be extracted",
                        required=True)
    parser.add_argument('-k', '--key', metavar='KEY',
                        help="Key whose value will be extracted. "
                        "If the key is named 'external_cluster_mon_ips' or 'key', "
                        "then a specific type of YAML file structure is assumed "
                        "and a specific search will be conducted for those values",
                        required=True)
    opts = parser.parse_args(argv[1:])
    return opts

def parse_yaml(yaml_file):
    with open(yaml_file, 'r') as f:
        try:
            the_data = yaml.safe_load(f)
            return the_data
        except Exception:
            raise RuntimeError(
                'Invalid YAML file: {yaml_data_file}'.format(
                yaml_data_file=yaml_file))
    return -1

def get_key(keys):
    for key in keys:
        if key['name'] == 'client.external':
            return key['key']
    return 'not found'

def get_external_cluster_mon_ips(inv):
    ips=[]
    # which roles have the ceph mon service running?
    roles = inv['mons']['children'].keys()
    # for those roles, get their hosts
    for role in roles:
        hosts = inv[role]['hosts']
        # for those hosts, get their storage IPs
        # assumes network isolation is used with standard names
        for host in hosts:
            ips.append(inv[role]['hosts'][host]['storage_ip'])
    return ','.join(ips)

OPTS = parse_opts(sys.argv)

for f in OPTS.yaml_file:
    the_data = parse_yaml(f)
    if OPTS.key == 'key':
        print(get_key(the_data['keys']))
    elif OPTS.key == 'external_cluster_mon_ips':
        print(get_external_cluster_mon_ips(the_data))
    else:
        try:
            value = the_data[OPTS.key]
            print(value)
        except:
            print("not found")
            
