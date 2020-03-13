# Use tripleo-lab to create an undercloud

I run the following on
[my hypervisor](http://blog.johnlikesopenstack.com/2018/08/pc-for-tripleo-quickstart.html).

```
 git clone git@github.com:cjeanner/tripleo-lab.git

 cd tripleo-lab

 cat inventory.yaml.example | sed s/IP_ADDRESS/127.0.0.1/g > inventory.yaml

 cp ~/ussuri/tripleo-lab/overrides.yml environments/overrides.yml

 cp ~/ussuri/tripleo-lab/overcloud.yml roles/undercloud/tasks/overcloud.yaml

 ansible-playbook --become -i inventory.yaml builder.yaml -e @environments/overrides.yml --skip-tags validations,metrics 
```

Workaround [issue with ~/.ssh/config](https://github.com/cjeanner/tripleo-lab/issues/55)

```
NEW_IP=$(grep undercloud /etc/hosts | awk {'print $1'})
OLD_IP=$(grep undercloud ~/.ssh/config | grep -v \# | awk {'print $3'})
sed -i s/$OLD_IP/$NEW_IP/g ~/.ssh/config
```

Not sure if this is a bug in tripleo-lab or something in my environment.