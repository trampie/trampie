# -*- ruby -*-

require File.join(File.dirname(File.expand_path(__FILE__)), 'lib/vcloud.rb')

desc "Launching and bootstraping instances by target (default=.*) repeat (default=20)"
task :boot, [:cluster, :target, :repeat] do |t, args|
  args.with_defaults(:cluster => "default", :target => ".*", :repeat => "20")
  begin
    print "[#{Time.new}] Creating and bootstrapping instances..."
    vcloud = VCloud.new(args)
    vcloud.log_config
    multi_task(vcloud, "boot", args[:target]) do |vnode|
      vnode.boot
    end
    print("\n")
    puts "[#{Time.new}] Managing /etc/hosts in cluster..."
    hosts(args, vcloud)
    puts "[#{Time.new}] Generating local ~/.ssh/config and /etc/host..."
    cluster_config(args, vcloud)
    show(args, vcloud)
    print "\n[#{Time.new}] The end\n"
  rescue Errno::ENOENT => e
    $stderr.puts(e.to_s)
  ensure
    vcloud.clear_tmp unless !vcloud
  end
end

desc "Bootstraping salt by target (default=.*)"
task :provision, [:cluster, :target] do |t, args|
  args.with_defaults(:cluster => "default", :target => ".*")
  begin
    print "[#{Time.new}] Provisioning instances..."
    vcloud = VCloud.new(args)
    vcloud.log_config
    multi_task(vcloud, "provision", args[:target]) do |vnode|
      vnode.provision
    end
    print "\n\n"
    show(args, vcloud)
    print "\n[#{Time.new}] The end\n"
  rescue Errno::ENOENT => e
    $stderr.puts(e.to_s)
  ensure
    vcloud.clear_tmp unless !vcloud
  end
end

desc "Destroying cluster instances by target (default=.*)"
task :kill, [:cluster, :target] do |t, args|
  args.with_defaults(:cluster => "default", :target => ".*")
  begin
    print "[#{Time.new}] Destroying instances...\n"
    vcloud = VCloud.new(args)
    vcloud.log_config
    multi_task(vcloud, "kill", args[:target]) do |vnode|
      vnode.kill
    end
    cluster_config(args, vcloud)
    show(args, vcloud)
    print "\n[#{Time.new}] The end\n"
  rescue Errno::ENOENT => e
    $stderr.puts(e.to_s)
  ensure
    vcloud.clear_tmp unless !vcloud
  end
end


desc "Manage /etc/hosts in cluster"
task :hosts, [:cluster] do |t, args|
  args.with_defaults(:cluster => "default")
  begin
    puts "[#{Time.new}] Managing /etc/hosts in cluster..."
    vcloud = VCloud.new(args)
    hosts(args, vcloud)
    show(args, vcloud)
    print "\n[#{Time.new}] The end\n"
  rescue Errno::ENOENT => e
    $stderr.puts(e.to_s)
  ensure
    vcloud.clear_tmp unless !vcloud
  end
end

desc "Generates local ~/.ssh/config and /etc/host"
task :config, [:cluster] do |t, args|
  args.with_defaults(:cluster => "default")
  begin
    puts "[#{Time.new}] Generating local ~/.ssh/config and /etc/host..."
    vcloud = VCloud.new(args)
    cluster_config(args, vcloud)
    show(args, vcloud)
    print "\n[#{Time.new}] The end\n"
  rescue Errno::ENOENT => e
    $stderr.puts(e.to_s)
  ensure
    vcloud.clear_tmp unless !vcloud
  end
end

desc "Showing current state of cluster instances"
task :show, [:cluster] do |t, args|
  args.with_defaults(:cluster => "default")
  begin
    puts "[#{Time.new}] Showing instances..."
    vcloud = VCloud.new(args)
    show(args, vcloud)
    print "\n[#{Time.new}] The end\n"
  rescue Errno::ENOENT => e
    $stderr.puts(e.to_s)
  ensure
    vcloud.clear_tmp unless !vcloud
  end
end

desc "Executing vagrant command target (default=.*)"
task :vagrant, [:command, :cluster, :target] do |t, args|
  args.with_defaults(:cluster => "default", :target => ".*")
  begin
    print "[#{Time.new}] Executing vagrant command..."
    vcloud = VCloud.new(args)
    multi_task(vcloud, "vagrant", args[:target]) do |vnode|
      vnode.vagrant(args[:command])
    end
    print "\n[#{Time.new}] The end\n"
  rescue Errno::ENOENT => e
    $stderr.puts(e.to_s)
  ensure
    vcloud.clear_tmp unless !vcloud
  end
end

desc "Rsyncing configured synced folders"
task :sync, [:cluster] do |t, args|
  args.with_defaults(:cluster => "default")
  begin
    puts "[#{Time.new}] Syncing folders..."
    vcloud = VCloud.new(args)
    multi_task(vcloud, "sync", ".*") do |vnode|
      if vnode.synced_folders.length > 0
        vnode.sync
      end
    end
    print "\n[#{Time.new}] The end\n"
  rescue Errno::ENOENT => e
    $stderr.puts(e.to_s)
  ensure
    vcloud.clear_tmp unless !vcloud
  end
end

def multi_task(vcloud, task_name, target, &block)
  vcloud.foreach(target) do |vnode|
    Rake::Task.define_task("#{task_name}_#{vnode.name}") do |name|
      block.call(vnode)
    end
  end
  target_def = vcloud.targets(target).map {|x| "#{task_name}_#{x}"}
  Rake::MultiTask.define_task("#{task_name}_all" => target_def)
  Rake::Task["#{task_name}_all"].invoke
end

def show(args, vcloud)
  multi_task(vcloud, "show", ".*") do |vnode|
    vnode.show
  end
  vcloud.print_status
end

def cluster_config(args, vcloud)
  ssh_config = []
  etc_host = []
  multi_task(vcloud, "cluster_config", ".*") do |vnode|
    ssh_config_chunk = vnode.generate_ssh_config
    ssh_config.push(ssh_config_chunk)
    etc_host.push(vnode.convert_to_host(ssh_config_chunk))
  end
  vcloud.replace_block_in_file("#{Dir.home()}/.ssh/config", ssh_config.join("\n").strip)
  vcloud.replace_block_in_file("/etc/hosts", etc_host.join("\n").strip)
end

def hosts(args, vcloud)
  nic_interfaces = {}
  multi_task(vcloud, "ssh_nic", ".*") do |vnode|
    nic_interfaces.merge!(vnode.fetch_nic)
  end
  external_ips = {}
  multi_task(vcloud, "ssh_info", ".*") do |vnode|
    ssh_config_chunk = vnode.generate_ssh_config
    external_ips[vnode.name] = vnode.convert_to_ip(ssh_config_chunk)
  end
  multi_task(vcloud, "hosts", ".*") do |vnode|
    vnode.update_host_file(nic_interfaces, external_ips)
  end
end

# Copyright (c) 2014 Nokia Solutions and Networks Oy Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.
