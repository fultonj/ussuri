# Ussuri

Every OpenStack cycle I end up with scripts I revise to make
development easier. This is where I'm storing the scripts for the
Ussuri cycle.

## How I use

- Use [tripleo-lab overrides](tripleo-lab) to deploy an undercloud
- Run the following on undercloud initialize it for work (git clone
  development repos and set up a local container registry)
```
git clone git@github.com:fultonj/ussuri.git
pushd ussuri/init
./git-init.sh tht
./containers.sh
popd
```
- Deploy a [standard](standard), [dcn](dcn), or [glance](glance) deployment.
