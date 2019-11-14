#!/usr/bin/env bash
# Filename:                git-init.sh
# Description:             configures my git env
# Supported Langauge(s):   GNU Bash 4.2.x
# Time-stamp:              <2019-09-24 16:47:06 fultonj> 
# -------------------------------------------------------
# Clones the repos that I am interested in.
# -------------------------------------------------------
if [[ $1 == 'tht' ]]; then
    pushd ~
    declare -a repos=(
        'openstack/tripleo-heat-templates' \
        'openstack/tripleo-common'\
        'openstack/tripleo-validations'\
        'openstack/tripleo-ansible'\
	);
fi
# -------------------------------------------------------
if [[ $# -eq 0 ]]; then
    # uncomment whatever you want
    declare -a repos=(
                      # 'openstack/tripleo-heat-templates' \
		      # 'openstack/tripleo-common'\
                      # 'openstack/tripleo-ansible' \
                      # 'openstack/tripleo-validations' \
                      # 'openstack/python-tripleoclient' \	
		      # 'openstack/puppet-ceph'\
		      #'openstack/heat'\
		      # 'openstack-infra/tripleo-ci'\
		      # 'openstack/tripleo-puppet-elements'\
		      # 'openstack/tripleo-specs'\
		      # 'openstack/os-net-config'\
		      # 'openstack/tripleo-docs'\
		      # 'openstack/tripleo-quickstart'\
		      # 'openstack/tripleo-quickstart-extras'\
		      #'openstack/tripleo-repos' 
		      #'openstack/puppet-nova'\
		      #'openstack/puppet-tripleo'\
		      # add the next repo here
    );
fi
# -------------------------------------------------------
gerrit_user='fultonj'
git config --global user.email "fulton@redhat.com"
git config --global user.name "John Fulton"
git config --global push.default simple
git config --global gitreview.username $gerrit_user

git review --version
if [ $? -gt 0 ]; then
    echo "installing git-review from upstream"
    dir=/tmp/$(date | md5sum | awk {'print $1'})
    mkdir $dir
    pushd $dir
    if [[ $(grep 7 /etc/redhat-release | wc -l) == 1 ]]; then
        curl http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/g/git-review-1.24-5.el7.noarch.rpm > git-review-1.24-5.el7.noarch.rpm
        sudo yum localinstall git-review-1.24-5.el7.noarch.rpm -y
    fi
    if [[ $(grep 8 /etc/redhat-release | wc -l) == 1 ]]; then
        if [[ ! -e /usr/bin/python3 ]]; then
            sudo dnf install python3 -y
        fi
        curl http://people.redhat.com/~iwienand/1564233/git-review-1.26.0-1.fc28.noarch.rpm > git-review-1.26.0-1.fc28.noarch.rpm
        sudo dnf install -y git-review-1.26.0-1.fc28.noarch.rpm
    fi
    popd 
    rm -rf $dir
fi 

for repo in "${repos[@]}"; do
    dir=$(echo $repo | awk 'BEGIN { FS = "/" } ; { print $2 }')
    if [ ! -d $dir ]; then
	git clone https://git.openstack.org/$repo.git
	pushd $dir
	git remote add gerrit ssh://$gerrit_user@review.openstack.org:29418/$repo.git
	git review -s
	popd
    else
	pushd $dir
	git pull --ff-only origin master
	popd
    fi
done

# -------------------------------------------------------
if [[ $1 == 'tht' ]]; then
    if [[ ! -e ~/templates ]]; then
        ln -v -s ~/tripleo-heat-templates ~/templates
    fi
    if [[ ! -d /usr/share/tripleo-common/playbooks.bak ]]; then
        sudo mv -v /usr/share/tripleo-common/playbooks{,.bak}
    fi
    if [[ -d ~/tripleo-common/playbooks ]]; then
        sudo ln -f -v -s ~/tripleo-common/playbooks /usr/share/tripleo-common/playbooks
    fi
    if [[ -d ~/tripleo-common/roles/  ]]; then
        if [[ ! -d ~/dist ]]; then mkdir ~/dist; fi
        for D in $(ls ~/tripleo-common/roles/); do
            sudo mv /usr/share/ansible/roles/$D ~/dist
            sudo ln -f -v -s ~/tripleo-common/roles/$D /usr/share/ansible/roles/$D
        done
    fi
    if [[ ! -d /usr/share/openstack-tripleo-validations.bak ]]; then
        sudo mv -v /usr/share/openstack-tripleo-validations{,.bak}
    fi
    if [[ -d ~/tripleo-validations ]]; then
        sudo ln -f -v -s ~/tripleo-validations /usr/share/openstack-tripleo-validations
    fi
    if [[ -d ~/tripleo-ansible ]]; then
        if [[ ! -d ~/dist ]]; then mkdir ~/dist; fi
        pushd /usr/share/ansible/
        # roles
        sudo mv -v tripleo-roles ~/dist
        sudo ln -f -v -s ~/tripleo-ansible/tripleo_ansible/roles tripleo-roles
        # playbooks
        sudo mv -v tripleo-playbooks ~/dist
        sudo ln -f -v -s ~/tripleo-ansible/tripleo_ansible/playbooks tripleo-playbooks
        # plugins
        sudo mv -v tripleo-plugins ~/dist
        sudo ln -f -v -s ~/tripleo-ansible/tripleo_ansible/ansible_plugins tripleo-plugins
        popd
    fi
    popd
    if [[ -e /home/stack/stackrc ]]; then
        echo 'source /home/stack/stackrc' >> ~/.bashrc
    fi
    echo 'alias os=openstack' >> ~/.bashrc    
fi
# -------------------------------------------------------
