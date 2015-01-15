# Overview #

Trampie is vagrant on stereoids.

### Features ###

* parallelization of vagrant commands
* supports multiple multi-vm environment
* easy to configure with YAML
* out of the box support for salt provisioner

### Dependencies ###

* vagrant 1.2+
* vagrant-hostmanager 1.4.0+

### Supports following providers ###

* vagrant-aws 0.4.0+

# Installation #

Install vagrant-hostmanager

```
vagrant plugin install vagrant-hostmanager
```

Fork template repository

```
git clone http://us-mv-gitlab.americas.nsn-net.net/devops/trampie-repo-template.git
cd trampie-repo-template
git submodule init
git submodule update
```

### Optional ###

Install vagrant-aws

```
vagrant plugin install vagrant-aws
```

# Usage #

### Command line ###

Execute `rake -T` for available commands

Common parameters:

* cluster - name of the cluster file, that holds definition of servers
* target - regexp that allows execution of commands for subset of servers
* repeat - repeats commands in case of failures

Commands:

```
# Creates instances and installs salt
rake boot[cluster,target,repeat]

# Generates entries in local ~/.ssh/config and /etc/host
rake config[cluster]

# Manage /etc/hosts in cluster
rake hosts[cluster]

# Destroys cluster instances
rake kill[cluster,target]

# Installs salt and dependencies
rake provision[cluster,target]

# Showing current state of cluster
rake show[cluster]

# Rsyncing configured synced folders
rake sync[cluster]

# Executing vagrant command without parameters
rake vagrant[command,cluster,target]
```

### Cluster definitions ###

Definitions of your cluster must be put into `/cluster` directory

There are one additional file that defines common parameters for your cluster

* `providers.yml` defines AWS keys, virtualbox settings, default parameters for instances, etc.

Example how to define providers:

```
$ cat cluster/providers.yml

# AWS regions
aws:
  # default attributes to apply to every aws region if not overriden
  defaults:
    batch_size: 10
    ssh_username: root
    nic: eth0
    type: m1.small
    ephemeral:
      device: /dev/vda2
      fstype: ext4

  region_name:
    id: aws_key
    key: aws_secret
    keyname: ssh_key_name
    availability_zones:
      - zone_name
    endpoint: http://hostname:8773/services/Eucalyptus
    security_groups:
      - security_group_name
    proxy: http://proxy_host:proxy_port
    ssh_keyfile: escloc55.pem

# Virtualbox providers
virtualbox:
  defaults:
    batch_size: 1
    ssh_username: vagrant
    box: precise64
    box_url: http://files.vagrantup.com/precise64.box
  my_box:
    # which interface to use to obtain private ip
    nic: eth1
    # how many instance can be create in parallel
    batch_size: 1
    # which network interface to bind bridged network
    nic_name: "en1: Wi-Fi (AirPort)"


```


Example how to define cluster:

```
$ cat cluster/sample_cluster.yml

# default attributes to apply to every server instance if not overriden
defaults:
  # settings to be applied on master config
  master:
    syndic_master_port: 1812  # refer to salt config parameters
    publish_port: 1813
    ret_port: 1812
  # settings to be applied on minion config
  minion:
    master: default-master
  # grains to be applied for all minions
  grains:
    roles:
      - java.openjdk

default-master:
  master:
  # supports vagrant settings like synced_folders
  synced_folders:
    ./states: /srv/states
    ./pillar: /srv/pillar
  # or forwarding ports
  forwarded_ports:
    80: 80

# using [] u can specify how many instance of this kind needs to be created
server-[10]:
  # will be combined with default grains
  grains:
     roles:
       - worker
     tags:   # grains can be anything
       - vbox
     attributes: # can be nested as well
       rack: 1024

```

### Credentials ###

Contains certificates for your cloud instances needs to specified through ```ssh_keyfile``` in either defaults, provider defaults or instance definition itself:

### Provisioners ###

Supports out of the box:

* Saltstack [http://docs.vagrantup.com/v2/provisioning/salt.html]()

Feel free to contribute
