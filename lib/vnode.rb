require 'yaml'
require 'erb'
require 'ostruct'
require 'tempfile'
require 'json'
require 'pathname'
require 'zlib'

class CreateStatus

  attr_accessor :host, :state

  def initialize(host)
    @host = host
  end

end

class VNode

  # name = "hadoop-ha-1"
  # name = "hadoop-master"
  # cluster_name = "hadoop"
  def initialize(name, attrs, provider, cluster_name, repeat)
    @name = name
    @provider = provider
    attrs["grains"] = {"cluster_name" => cluster_name, "provider" => provider.attributes }.merge(attrs["grains"])
    @attributes = attrs
    @repeat = repeat.to_i
    @is_master = name == (attrs["minion"] || {})["master"]
    @cluster = cluster_name
    current_file = File.expand_path(__FILE__)
    @cwd = File.dirname(File.dirname(current_file))
    @status = CreateStatus.new(@name)
    zone_index = Zlib.crc32(@name) % availability_zones.length
    @zone = availability_zones[zone_index]
  end

  def method_missing(m, *args, &block)
    if @attributes[m.to_s] != nil
      @attributes[m.to_s]
    else
      @provider.send(m.to_s)
    end
  end

  def name
    @name
  end

  def master?
    @is_master
  end

  def status
    @status
  end

  def attributes
    @attributes
  end

  # availability_zones = ["e1", "e2"]
  def availability_zone
    @zone
  end

  def region_with_zone
    if location_scope == "region"
      region
    else
      "#{region}_#{@zone}"
    end
  end

  def fetch_nic
    log = tmp_log("generate_nic")
    result = execute_system("vagrant ssh #{@name} -c 'ifconfig #{nic} | grep \"inet addr\" | cut -d : -f 2 | cut -d \" \" -f 1' -- -q -t -n", log)
    nic_hash = {}
    if result
      ip = File.read(log[0]).rstrip
      ip.match(/\d+.\d+.\d+.\d+/) do |m|
        nic_hash = {@name => m.to_s}
      end
    end
    nic_hash
  end


  def update_host_file(nic_interfaces, external_ips)
    dumped_nic = {"nics" => nic_interfaces, "public_ips" => external_ips}.to_json
    result = execute_system("vagrant hostmanager #{@name} --provider #{@provider.provider}",
      out_log, {'SALT_NICS' => dumped_nic})
    if !result
      print " [#{@name}] /etc/hosts management failed "
    end
  end

  def generate_ssh_config
    log = tmp_log("generate_ssh_config")

    result = execute_system("vagrant ssh-config #{@name}", log)
    if result
      content = File.read(log[0])
      content.gsub(/.*\[WARNING\].*/, '')
    else
      ""
    end
  end

  def convert_to_ip(ssh_config)
    props = convert_to_hash(ssh_config)
    props['hostname'] || "127.0.0.1"
  end

  def convert_to_hash(ssh_config)
    stripped = ssh_config.downcase.strip
    if (stripped.empty?)
      {}
    else
      entries = stripped.split("\n")
      properties = entries.collect do |entry|
        key_val = entry.split("\s")
        if (key_val.length > 1)
          { key_val[0].strip => key_val[1].strip }
        else
          {}
        end
      end
      properties.inject(:merge)
    end
  end

  def convert_to_host(ssh_config)
    properties = convert_to_hash(ssh_config)
    if (properties.has_key?("host") && properties.has_key?("hostname"))
      "#{properties['hostname']}\t#{properties['host']}"
    else
      ""
    end
  end

  def kill
    result = execute_system("vagrant destroy #{@name} -f", out_log)
    if result
      @status.state = "not created"
    else
      @status.state = "running"
    end
  end

  def vagrant(command)
    result = execute_system("vagrant #{command} #{@name}", out_log)
    if !result
      print " [#{@name}] #{command} failed "
    end
  end

  def show
    log = tmp_log("show")
    result = execute_system("vagrant status #{@name}", log)
    if result
      value = File.read(log[0])
      splitted = value.split("\n")
      hash = Hash[splitted.map.with_index.to_a]
      index = hash['Current machine states:']
      status_line = splitted[index + 2]
      status_cut = status_line.split(@name)[1].strip.split("\s")
      @status.state = status_cut.slice(0, status_cut.size - 1).join(" ")
    else
      @status.state = "unknown"
    end
    @status
  end

  def sync
    if !is_virtualbox?
      synced_folders.each_pair do |local_path, remote_path|
        local_path = "#{local_path}/" if local_path !~ /\/$/
        base_dir = File.join(@cwd, "..")
        local_path = File.join(base_dir, local_path)
        result = execute_system("rsync --archive -z #{local_path} #{name}:#{remote_path}", out_log)
        if !result
          print " [#{@name}] rsync failed for #{local_path} => #{remote_path}"
        end
      end
    end
  end

  def provision
    print("*")
    result = execute_system("vagrant provision #{@name}", out_log)
    if !result
      print " [#{@name}] salt provisioning failed "
    end
    print(".")
  end

  def create
    begin
      @provider.acquire_lock
      print("-")
      result = true
      in_loop do
        result = execute_system("vagrant up #{@name} --provider #{@provider.provider} --no-parallel --no-provision", out_log)
      end
      if result
        @status.state = "running"
      else
        @status.state = "not created"
      end
      print("|")
    ensure
      @provider.release_lock
    end
  end

  def boot
    if show.state != "running"
      create
      if show.state == "running"
        provision
      end
    end
  end

  def config(template)
    template_path = File.join(@cwd, template)
    tmp_dir = File.join(@cwd, ".tmp")
    FileUtils.mkdir_p tmp_dir
    tempfile = Tempfile.new("salty-vagrant", tmpdir = tmp_dir)
    write_path = tempfile.path
    tempfile.close!

    template_content = File.read(template_path)

    evaluated_template = ERB.new(template_content, nil, '-').result(OpenStruct.new(@attributes).instance_eval { binding })
    File.open(write_path , 'w') {|f| f.write(evaluated_template) }
      write_path
  end

  def log_config_info
    append_log("\nNode[#{@name}]:\n#{@attributes.to_yaml}#{@provider.attributes.to_yaml}\n")
  end

  def append_log(text)
    File.open(File.join(@cwd, "logs/#{@name}.log"), 'a+') { |file| file.write(text) }
  end

  private

  def execute_system(cmd_line, file_output, env_hash={})
    result = system(env_hash.merge(
      {'SALT_ENV' => @cluster,
        'VAGRANT_DOTFILE_PATH' => File.join(@cwd, '../.vagrant')}), cmd_line,
        :out => file_output, :err => out_log, :chdir => @cwd)
    result
  end

  def out_log
    [File.join(@cwd, "logs/#{@name}.log"), 'a+']
  end

  def tmp_log(cmd_name)
    tmp_dir = File.join(@cwd, ".tmp")
    FileUtils.mkdir_p tmp_dir
    tempfile = Tempfile.new(cmd_name, tmpdir = tmp_dir)
    write_path = tempfile.path
    tempfile.close!
    [write_path, 'w']
  end

  def in_loop(&block)
    repeat_counter = 1
    begin
      result = block.call
      repeat_counter += 1
      sleep_time = 2 * repeat_counter
      if !result
        sleep sleep_time
      end
    end while (!result and repeat_counter <= @repeat)
  end
end

# Copyright (c) 2014 Nokia Solutions and Networks Oy Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.
