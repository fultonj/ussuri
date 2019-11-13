# Use tripleo-lab to create an undercloud
```
 git clone git@github.com:cjeanner/tripleo-lab.git

 cd tripleo-lab

 cat inventory.yaml.example | sed s/IP_ADDRESS/127.0.0.1/g > inventory.yaml

 cp ~/ussuri/tripleo-lab/overrides.yml environments/overrides.yml

 ansible-playbook --become -i inventory.yaml builder.yaml -e @environments/overrides.yml --skip-tags validations,metrics 
```
