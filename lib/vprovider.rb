require File.join(File.dirname(File.expand_path(__FILE__)), "semaphore.rb")

class VProvider
  def initialize(name, values)
    @name = name
    @attributes = values
    @defaults = {"batch_size" => "100", "proxy" => "", "noproxy" => "",
      "box" => "dummy", "box_url" => "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box",
      "forwarded_ports" => {}, "memory" => "512", "cpus" => "1", "synced_folders" => {}, "region" => "",
      "availability_zones" => [""], "location_scope" => "availability_zone" }
    @sem = Semaphore.new(batch_size.to_i)
  end

  def name
    @name
  end

  def attributes
    @attributes
  end

  def is_virtualbox?
    @attributes['provider'] == "virtualbox"
  end

  def is_aws?
    @attributes['provider'] == "aws"
  end

  def release_lock
    @sem.signal
  end

  def acquire_lock
    @sem.wait
  end

  def method_missing(m, *args, &block)
    if @attributes[m.to_s] != nil
      @attributes[m.to_s]
    elsif @defaults[m.to_s] != nil
      @defaults[m.to_s]
    else
      super
    end
  end

end

# Copyright (c) 2014 Nokia Solutions and Networks Oy Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.
