#!/usr/bin/env bash

# Populates control-plane/ceph_keys.yaml and dcn0/ceph_keys.yaml with 
# consistent values for CephExtraKeys and CephExternalMultiConfig
# as described in https://bugzilla.redhat.com/show_bug.cgi?id=1808424
# so that the deployer can do steps 1-3 below.
# 
# This will enable the deployer to:
# 
# 1. Deploy central with a ceph key for the central glance pool which may
#    by used by any DCN node via CephExtraKeys
# 
# 2. Deploy dcn0 with it's own ceph cluster and the ability to use the key
#    from step1 to access a second ceph cluster via CephExternalMultiConfig
#    and also create a key with CephExtraKeys that can access the glance
#    pool on the dcn0 ceph cluster
# 
# 3. Deploy dcn1 with it's own ceph cluster and the ability to use the key
#    from step1 to access a second ceph cluster via CephExternalMultiConfig
#    and also create a key with CephExtraKeys that can access the glance
#    pool on the dcn1 ceph cluster
#
# 4. Update central and pass CephExternalMultiConfig with the keys created
#    from steps 2 and 3 so it can write to the glance pools at the DCN sites
#    via CephExternalMultiConfig
#
# The above is another way to implement the pattern described in
#  https://bugzilla.redhat.com/show_bug.cgi?id=1760941
