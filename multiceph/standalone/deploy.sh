#!/bin/bash

export INTERFACE=eth0
export IP=192.168.24.254
export NETMASK=24
export DNS_SERVERS=192.168.122.1
export NTP_SERVERS=pool.ntp.org
export INTERNAL_CEPH=0
export EXTERNAL_CEPH=1

cat <<EOF > $HOME/overrides.yaml
parameter_defaults:
  CertmongerCA: local
  CloudName: $IP
  ControlPlaneStaticRoutes: []
  Debug: true
  DeploymentUser: $USER
  DnsServers: $DNS_SERVERS
  NtpServer: $NTP_SERVERS
  # needed for vip & pacemaker
  KernelIpNonLocalBind: 1
  DockerInsecureRegistryAddress:
  - $IP:8787
  NeutronPublicInterface: $INTERFACE
  # domain name used by the host
  NeutronDnsDomain: localdomain
  # re-use ctlplane bridge for public net
  NeutronBridgeMappings: datacentre:br-ctlplane
  NeutronPhysicalBridge: br-ctlplane
  # enable to force metadata for public net
  #NeutronEnableForceMetadata: true
  StandaloneEnableRoutedNetworks: false
  StandaloneHomeDir: $HOME
  StandaloneLocalMtu: 1400
  NovaComputeLibvirtType: qemu
  PasswordAuthentication: 'yes'
  StandaloneExtraConfig:
    cinder::backend_host: ''
    tripleo::firewall::firewall_rules:
      '004 accept ssh from libvirt default subnet 192.168.122.0/24 ipv4':
        dport: [22]
        proto: tcp
        source: 192.168.122.0/24
        action: accept
  LocalCephAnsibleFetchDirectoryBackup: /tmp/ceph_ansible_fetch
  ContainerHealthcheckDisabled: true
EOF

if [[ $INTERNAL_CEPH -eq 1 ]]; then
    # only for usecase2
    cat <<EOF > $HOME/internal_ceph.yaml
parameter_defaults:
  CephAnsibleDisksConfig:
    osd_scenario: lvm
    osd_objectstore: bluestore
    lvm_volumes:
      - data: data-lv2
        data_vg: vg2
        db: db-lv2
        db_vg: vg2
  CephAnsibleExtraConfig:
    cluster_network: 192.168.122.0/24
    public_network: 192.168.122.0/24
  CephPoolDefaultPgNum: 32
  CephPoolDefaultSize: 1
  CephAnsiblePlaybookVerbosity: 3
EOF
fi

if [[ $EXTERNAL_CEPH -eq 1 ]]; then
    cat <<EOF > $HOME/external_ceph.yaml
parameter_defaults:
  # ssh'd into deployed cent0 and read it from conf
  CephClusterFSID: '1d9c75c0-3c09-4675-82ba-fbaf3a022da6'
  # directly from ceph/all.yml client.openstack
  CephClientKey: 'AQCwmeRcAAAAABAA6SQU/bGqFjlfLro5KxrB1Q=='
  CephExternalMonHost: '192.168.122.251'
  CephClusterName: 'cent0'
  CephAnsibleExtraConfig:
    mon_host_v1: { 'enabled': False }
EOF
fi

if [[ $EXTERNAL_CEPH -eq 2 ]]; then
    cat <<EOF > $HOME/external_ceph.yaml
parameter_defaults:
  CephMultiBackendsHash:
    ceph0:
      CephClusterFSID: '1d9c75c0-3c09-4675-82ba-fbaf3a022da6'
      CephClientKey: 'AQCwmeRcAAAAABAA6SQU/bGqFjlfLro5KxrB1Q=='
      CephExternalMonHost: 'cent0'
    ceph1:
      CephClusterFSID: '4b5c8c0a-ff60-454b-a1b4-9747aa737d19'
      CephClientKey: 'AQCwmeRcAAAAABAA6SQU/bGqFjlfLro5KxrB1Q=='
      CephExternalMonHost: 'cent1'
EOF
fi

if [[ ! -d ~/templates ]]; then
    if [[ ! -d ~/tripleo-heat-templates ]]; then
        ln -s /usr/share/openstack-tripleo-heat-templates ~/templates
    else
        ln -s ~/tripleo-heat-templates ~/templates
    fi
fi

sudo sh -c "echo $(hostname) > /etc/hostname ; hostname -F /etc/hostname"

# iptables hack
sudo iptables -I INPUT 1 -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT

sudo openstack tripleo deploy \
  --templates ~/templates \
  --local-ip=$IP/$NETMASK \
  -e ~/templates/environments/standalone.yaml \
  -e ~/templates/environments/ceph-ansible/ceph-ansible-external.yaml \
  -r ~/templates/roles/Standalone.yaml \
  -e $HOME/containers-env-file.yaml \
  -e $HOME/overrides.yaml \
  -e $HOME/external_ceph.yaml \
  --output-dir $HOME \
  --standalone

# for usecase2
# -e $HOME/multiceph/internal_ceph.yaml \
