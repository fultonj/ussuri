# DCN (Distributed Compute Node)

I use these templates and scripts to simulate a DCN deployment.

- Use [control-plane/deploy.sh](control-plane/deploy.sh) to deploy controllers with [control-plane/overrides.yaml](control-plane/overrides.yaml)
- Use [dcn0/deploy.sh](dcn0/deploy.sh) to deploy HCI node(s) in AZ dcn0 with [dcn0/overrides.yaml](dcn0/overrides.yaml) and [dcn0/ceph.yaml](dcn0/ceph.yaml)
- Use [dcnN.sh](dcnN.sh) to deploy additional HCI nodes in AZ dcn1, dcn2, ... 
- Use [test.sh](test.sh) to test that the DCN deployment is working

Alternatively, you can do this which will do all of the above for you:

`time ./master.sh 2>&1 | tee -a master.log`
