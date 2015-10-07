# -*- mode: ruby -*-
# vi: set ft=ruby :

require File.join(File.dirname(File.expand_path(__FILE__)), 'lib/vcloud.rb')

Vagrant.configure("2") do |config|
  config.vm.synced_folder '.', '/vagrant', :disabled => true
  config.hostmanager.manage_host = false
  vcloud = VCloud.new({ :cluster => ENV['SALT_ENV'] || 'default' })
  vcloud.foreach(".*") do |vnode|
    config.vm.define vnode.name do |node|
      node.vm.hostname = vnode.name
      vnode.synced_folders.each_pair do |local_path, remote_path|
        node.vm.synced_folder File.join('../', local_path), remote_path
      end

      node.hostmanager.ip_resolver = proc do |vm, resolving_vm|
        vcloud.resolve_ip(vm, resolving_vm)
      end


      node.vm.box = vnode.box
      node.vm.box_url = vnode.box_url
      node.vm.boot_timeout = 600

      if vnode.is_virtualbox?
        node.vm.network :public_network, :bridge => vnode.nic_name
        node.ssh.forward_agent = true
        node.vm.provider :virtualbox do |prov|
          prov.customize [
            "modifyvm", :id,
            "--memory", vnode.memory,
            "--cpus", vnode.cpus
          ]
        end
        vnode.forwarded_ports.each_pair do |guest, host|
          node.vm.network :forwarded_port, guest: guest, host: host
        end
      elsif vnode.is_aws?
        node.vm.provider :aws do |prov,override|
          prov.instance_type = vnode.type
          prov.instance_ready_timeout = 600
          prov.region = vnode.provider

          override.ssh.username = vnode.ssh_username
          override.ssh.private_key_path = "../credentials/#{vnode.ssh_keyfile}"
          prov.region_config vnode.provider do |region|
            region.access_key_id = vnode.access_key
            region.secret_access_key = vnode.secret_key
            region.keypair_name = vnode.keyname
            region.availability_zone = vnode.availability_zone
            region.endpoint = vnode.region
            region.ami = vnode.ami
            region.security_groups = vnode.security_groups
          end
        end
      elsif vnode.is_openstack?
        node.vm.provider :openstack do |prov,override|
          prov.username = vnode.username
          override.ssh.username = vnode.ssh_username
          override.ssh.private_key_path = "../credentials/#{vnode.ssh_keyfile}"
          prov.flavor = vnode.flavor
          prov.image = vnode.image
          prov.password = vnode.api_key
          prov.openstack_auth_url = vnode.openstack_auth_url
          prov.tenant_name = vnode.tenant
          prov.keypair_name = vnode.keypair_name
          prov.availability_zone = vnode.availability_zone
          prov.security_groups = vnode.security_groups
          prov.networks = vnode.networks
          prov.floating_ip_pool = vnode.floating_ip_pool
          prov.sync_method = "none"
          prov.rsync_includes = []
        end
      end


      node.vm.provision :shell do |s|
        s.path = "scripts/bootstrap.sh"
        proxy = ""
        if vnode.proxy != ""
            proxy = "-p #{vnode.proxy}"
        end
        noproxy = ""
        if vnode.noproxy != ""
            noproxy = "-x #{vnode.noproxy}"
        end
        s.args = "-n #{vnode.name} #{proxy} #{noproxy}"
      end

      node.vm.provision :salt do |salt|
        salt.master_config = vnode.config("config/master.erb")
        salt.minion_config = vnode.config("config/minion.erb")
        salt.minion_key = "config/minion.pem"
        salt.minion_pub = "config/minion.pub"
        salt.master_key = "config/master.pem"
        salt.master_pub = "config/master.pub"
        salt.install_master = vnode.master?
        salt.install_type = "git"
        salt.install_args = "v2015.8.0"
        salt.bootstrap_options = "-P -F -c /tmp"
        salt.verbose = false
      end

      node.vm.provision :shell, inline: "echo instance_creation_date: $(date +%s%N) > /etc/salt/grains"

    end
  end
end

# Copyright (c) 2014 Nokia Solutions and Networks Oy Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.
