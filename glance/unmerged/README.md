# Pulling in Unmerged Changes

What patches are missing to make the POC work and how do I apply them?

## Puppet TripleO

- Modify the overcloud image so that `/etc/puppet/modules/puppet-tripleo` contains [glance multistore support for puppet-tripleo](https://review.opendev.org/#/c/704373)
- I use [overcloud-image-tweak.sh](overcloud-image-tweak.sh) to do this
  
## TripleO Heat Templates (THT)

There are no missing tht patches at this time. 

- Use [git-init.sh](../init/git-init.sh)

## Glance 

There are no missing glance patches at this time.

- The RDO glance image has all the necessary patches
  - E.g. `sudo podman exec -ti glance_api grep store_exceptions
    /usr/lib/python2.7/site-packages/glance/async_/flows/api_image_import.py`
    turns up things it should from [this patch](https://review.opendev.org/#/c/667132/25/glance/async_/flows/api_image_import.py)

