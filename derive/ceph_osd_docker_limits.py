#!/usr/bin/env python
#
# ceph_osd_docker_limits.py 
# - script to compute docker CPU and memory limits
#
# input parameters:
#
# percent of CPU to use for Ceph OSDs
# CPU cores per host
# percent of memory to use for Ceph OSDs
# memory per host (GB)
# block devices per host
# block device type (HDD/SSD/NVM)

import os, sys
from sys import argv

dev_types = [ 'HDD', 'SSD', 'NVM' ]
def usage(msg):
    print('ERROR: %s' % msg)
    print('usage: ceph_osd_docker_limits.py cpu-pct cpu-cores mem-pct mem-GB block-devs-per-host block-dev-type')
    print('block-dev-type can be HDD, SSD or NVM')
    sys.exit(1)

if len(argv) < 7:
    usage('not enough command line parameters')
cpu_pct = float(argv[1])
cpu_cores = int(argv[2])
mem_pct = float(argv[3])
mem_GB = int(argv[4])
devs_per_host = int(argv[5])
dev_type = argv[6].upper()

# echo values that the user specified

print('')
print('-- user-specified input parameters:')
print('CPU percentage available for OSDs: %f' % cpu_pct)
print('CPU cores per host: %d' % cpu_cores)
print('memory percentage available for OSDs: %f' % mem_pct)
print('memory per host (GB): %d' % mem_GB)
print('devices per host: %d' % devs_per_host)
print('device type: %s' % dev_type)

if not dev_types.__contains__(dev_type):
    usage('block-dev-type not recognized')
if dev_type == 'HDD':
    osds_per_dev = 1
    cores_per_osd = 2
elif dev_type == 'SSD':
    osds_per_dev = 1
    cores_per_osd = 4
elif dev_type == 'NVM':
    osds_per_dev = 4
    cores_per_osd = 3

if cpu_pct < 0.0 or cpu_pct > 100.0:
    usage('CPU percentage must be between 0 and 100')
if mem_pct < 0.0 or mem_pct > 100.0:
    usage('memory percentage must be between 0 and 100')
if cpu_cores < 1:
    usage('CPU cores must be a positive integer')
if mem_GB < 1:
    usage('memory per host in GB must be a positive integer')
if devs_per_host < 1:
    usage('devices per host must be a positive integer')

osds_per_host = osds_per_dev * devs_per_host
cores_needed = osds_per_host * cores_per_osd
cores_limit = int(cpu_cores * cpu_pct/100.0)
cores_available = min(cores_needed, cores_limit)
mem_available = max(3., int(mem_GB * mem_pct/100.0))
mem_per_osd = mem_available / osds_per_host
cores_per_osd = cores_available / osds_per_host

print('')
print('-- derived parameters for ceph-ansible ceph_conf_overrides OSD section:')
print('ceph_osd_docker_memory_limit: %d' % int(mem_per_osd))
print('ceph_osd_docker_cpu_limit: %d' % int(cores_per_osd))

