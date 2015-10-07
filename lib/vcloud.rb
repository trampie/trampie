require 'yaml'
require 'erb'
require 'ostruct'
require 'tempfile'
require 'json'
require 'pathname'
require File.join(File.dirname(File.expand_path(__FILE__)), "vprovider.rb")
require File.join(File.dirname(File.expand_path(__FILE__)), "vnode.rb")

class VCloud

  # cluster = "perf"
  def initialize(args)
    @cluster = args[:cluster] || "default"
    @repeat = (args[:repeat] || "5").to_i
    cwd = cwd()
    providers_def = YAML::load_file(File.join(cwd, '../cluster/providers.yml'))
    cluster_def = YAML::load_file(File.join(cwd, "../cluster/#{@cluster}.yml"))
    providers = as_providers(providers_def)
    @cluster_map = as_cluster_map(cluster_def, providers, @cluster, @repeat)
  end

  def log_config
    @cluster_map.each_value do |vnode|
      vnode.log_config_info()
    end
  end

  def foreach(target, &block)
    matcher = /\A#{target}\Z/
    @cluster_map.each_value do |vnode|
      if matcher.match(vnode.name) != nil
        block.call(vnode)
      end
    end
  end

  def node(name)
    @cluster_map[name]
  end

  def targets(target)
    matcher = /\A#{target}\Z/
    @cluster_map.keys.select{|vnode_name| matcher.match(vnode_name) != nil}
  end

  def print_status
    statuses = []
    foreach(".*") do |vnode|
      statuses.push(vnode.status)
    end
    printf("%-30s %20s\n", "Host", "State")
    printf("%s\n", "-" * 55)
    statuses.each do |status|
      printf("%-30s %20s\n", status.host, status.state)
    end
  end

  def resolve_ip(vm, resolving_vm)
    config = JSON.parse(ENV['SALT_NICS'])
    nics = config['nics']
    public_ips = config['public_ips']
    resolving_vnode = @cluster_map[resolving_vm.config.vm.hostname]
    vnode = @cluster_map[vm.config.vm.hostname]
    host_region = resolving_vnode.region_with_zone
    guest_region = vnode.region_with_zone
    if host_region != guest_region && !vnode.is_virtualbox?
      public_ips[vnode.name]
    else
      nics[vnode.name] || public_ips[vnode.name]
    end
  end

  def clear_tmp
    begin
      FileUtils.rm_rf(File.join(cwd(), ".tmp"))
    rescue Errno::ENOENT
      #do nothing
    end
  end

  def replace_block_in_text(original_block, block_of_text)
    block_header = "## trampie-start id: #{@cluster}\n"
    block_footer = "## trampie-stop id: #{@cluster}\n"
    # Pattern for finding existing block
    header_pattern = Regexp.quote(block_header)
    footer_pattern = Regexp.quote(block_footer)
    block = block_header + block_of_text + "\n" + block_footer
    pattern = Regexp.new("#{header_pattern}.*?#{footer_pattern}", Regexp::MULTILINE)
    # Replace existing block or append
    new_file_content =
      if original_block.match(pattern)
        original_block.sub(pattern, block)
      else
        "#{original_block.rstrip}\n\n#{block}"
      end
    # Clear out extra newlines left behind when block is empty
    new_file_content = new_file_content.rstrip + "\n"
    new_file_content
  end

  def replace_block_in_file(file, block_of_text)
    old_file_content = ""
    begin
      file = Pathname.new(file)
      old_file_content = file.read
    rescue Errno::ENOENT => e
    # do nothing
    end
    new_file_content = replace_block_in_text(old_file_content, block_of_text)
    file.open('w') { |io| io.write(new_file_content) }
  end

  private

  def cwd()
    current_file = File.expand_path(__FILE__)
    File.dirname(File.dirname(current_file))
  end

  def as_providers(providers_def)
    result = {}
    # providers = providers_def["aws"]
    providers_def.each_pair do |provider_type,providers|
      provider_defaults = providers["defaults"] || {}
      provider_defaults["provider"] = provider_type
      providers = providers.select{|k,v| k != "defaults"}
      providers.each_pair do |provider_name, provider_data|
        provider_data = deep_merge(provider_defaults, provider_data)
        result.merge!({provider_name => VProvider.new(provider_name, provider_data)})
      end
    end
    result
  end

  def deep_merge(first, second)
    merger = proc do |key, v1, v2|
      if Hash === v1 && Hash === v2
        v1.merge(v2, &merger)
      elsif Array === v1 && Array === v2
        v1 + v2
      else
        v2
      end
    end
    first.merge(second, &merger)
  end

  def as_cluster_map(cluster_def, providers, cluster_name, repeats)
    result = {}
    cluster_defaults = ({"master"=>{}, "minion"=>{}, "grains"=>{}}).merge(cluster_def["defaults"] || {})
    cluster_nodes = cluster_def.select{|k,v| k != "defaults"}

    # node_settings = nil
    # node_settings = cluster_nodes["hadoop-master"]
    cluster_nodes.each_pair do |node_name_pattern, node_settings|
      host_names = node_names(node_name_pattern)
      attrs = deep_merge(cluster_defaults, node_settings || {})
      host_names.each do |hostname|
        provider = providers[attrs["provider"]]
        result.merge!(hostname => VNode.new(hostname, attrs, provider, cluster_name, repeats))
      end
    end
    result
  end

  def node_names(node_name_pattern)
    matcher = /\A(?<prefix>.*)\[(?<nodes>\d+)\]\Z/
    matched = matcher.match(node_name_pattern)
    names = []
    if matched != nil
      node_no = matched[:nodes].to_i if matched[:nodes] != nil
      if node_no != nil and node_no > 0
        (1..node_no).each do |index|
          names.push("#{matched[:prefix]}#{index}")
        end
      else
        names.push(node_name_pattern)
      end
    else
      names.push(node_name_pattern)
    end
    names
  end

end


# Copyright (c) 2014 Nokia Solutions and Networks Oy Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.
