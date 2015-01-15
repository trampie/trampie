#!/bin/bash

# Copyright (c) 2014 Nokia Solutions and Networks Oy Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.

my_hostname=""
my_proxy=""
no_proxy=""
sudo mkdir -p "/tmp"
tmp_log="/tmp/shell_bootstrap.log"
sudo echo "" > $tmp_log
minion_default="/etc/default/salt-minion"
touch "$minion_default"
sudo apt-get install -q -y curl
#parsing options
while getopts ":n:p:x:" name
do
  case "$name" in
    n)
      my_hostname="$OPTARG"
      ;;
    p)
      my_proxy="$OPTARG"
      ;;
    x)
      no_proxy="$OPTARG"
      ;;
    *)
    ;;
  esac
done

if [ "$my_proxy" != "" ]
then
  # extract the protocol
  proto="$(echo $my_proxy | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  # remove the protocol
  url="$(echo ${my_proxy/$proto/})"
  # extract the user (if any)
  user="$(echo $url | grep @ | cut -d@ -f1)"
  # extract the host
  host_with_port="$(echo ${url/$user@/} | cut -d/ -f1)"
  host="$(echo $host_with_port | grep ':' | cut -d: -f1)"
  port="$(echo $host_with_port | grep ':' | cut -d: -f2-)"
  # extract the path (if any)
  path="$(echo $url | grep / | cut -d/ -f2-)"
fi

#set hostname
if [ "$my_hostname" != "" ]
then
  sudo echo $my_hostname > "/etc/hostname"
  sudo hostname -b "$my_hostname" >> $tmp_log
  if ! grep -q "# Touched by Trampie" "/etc/hosts"
  then
    sudo echo "# Touched by Trampie" > /etc/hosts
    sudo echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" >> /etc/hosts
    sudo echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
  fi
fi

#set http proxy
if [ "$my_proxy" != "" ]
then
  export http_proxy="$my_proxy"
  export https_proxy="$my_proxy"
  export ftp_proxy="$my_proxy"
  export HTTP_PROXY="$my_proxy"
  export HTTPS_PROXY="$my_proxy"
  export FTP_PROXY="$my_proxy"
  export no_proxy="$no_proxy"
  export NO_PROXY="$no_proxy"

  proxy='"'$my_proxy'"'
  env_file="/etc/environment"

  noproxy='"'$no_proxy'"'
  patterns=("http_proxy=$proxy" "https_proxy=$proxy" "ftp_proxy=$proxy" "HTTP_PROXY=$proxy" "HTTPS_PROXY=$proxy" "FTP_PROXY=$proxy")


  #setting proxy in /etc/environment
  if ! [ -f "$env_file" ]
  then
    sudo mkdir -p "/etc" >> $tmp_log
    sudo touch $env_file >> $tmp_log
    sudo touch $minion_default >> %tmp_log
  fi

  for pattern in "${patterns[@]}"
  do
    if ! grep -q $pattern "$env_file"
    then
      sudo echo $pattern >> $env_file
      sudo echo "export $pattern" >> $minion_default
    fi
  done

  no_proxy_patterns=("no_proxy=" "NO_PROXY=")

  for pattern in "${no_proxy_patterns[@]}"
  do
    if ! grep -q $pattern "$env_file"
    then
      sudo echo "$pattern$noproxy" >> $env_file
      sudo echo "export $pattern$noproxy" >> $minion_default
    fi
  done

  #keeping env in sudo mode
  sudo_file="/etc/sudoers"
  keep_proxy='Defaults env_keep += "http_proxy https_proxy ftp_proxy noproxy HTTP_PROXY HTTPS_PROXY FTP_PROXY NOPROXY"'
  if [ -f "$sudo_file" ]
  then
    if ! grep -q "$keep_proxy" "$sudo_file"
    then
      sudo echo $keep_proxy >> $sudo_file
    fi
  else
    sudo mkdir -p "/etc" >> $tmp_log
    sudo echo $keep_proxy > $sudo_file
  fi
fi

#set apt proxy
if [ "$my_proxy" != "" ]
then
  proxy='"'$my_proxy'"'
  #setting proxy in apt config (debian/ubuntu specific)
  apt_file="/etc/apt/apt.conf"
  apt_proxy='Acquire::http::Proxy '$proxy';'
  if [ -f "$apt_file" ]
  then
    if ! grep -q "$apt_proxy" "$apt_file"
    then
      sudo echo $apt_proxy >> $apt_file
      sudo apt-get -q -y update > /dev/null
    fi
  else
    mkdir -p "/etc/apt" >> $tmp_log
    sudo echo $apt_proxy > $apt_file
    sudo apt-get -q -y update >> $tmp_log
  fi
fi

#install git
sudo apt-get install -q -y git-core >> $tmp_log
sudo apt-get install -q -y python-setuptools >> $tmp_log

#set git proxy
if [ "$my_proxy" != "" ]
then
  sudo apt-get install -q -y socat >> $tmp_log
  gitproxy="/usr/bin/gitproxy"

  if ! [ -f "$gitproxy" ]
  then
    sudo mkdir -p "/usr/bin"
    sudo echo '#!/bin/sh' > "$gitproxy"
    sudo echo "_proxy=$host" >> "$gitproxy"
    sudo echo "_proxyport=$port" >> "$gitproxy"
    sudo echo 'exec socat STDIO PROXY:$_proxy:$1:$2,proxyport=$_proxyport' >> "$gitproxy"
    sudo chmod +x "$gitproxy" >> $tmp_log
    sudo git config --system core.gitproxy gitproxy >> $tmp_log
  fi

fi

#gitpython
if ! [ -f "/tmp/get-pip.py" ]
then
  if [ "$my_proxy" != "" ]
  then
    proxy='"'$my_proxy'"'
    curl --proxy $proxy https://bootstrap.pypa.io/get-pip.py --output /tmp/get-pip.py >> $tmp_log
  else
    curl https://bootstrap.pypa.io/get-pip.py --output /tmp/get-pip.py >> $tmp_log
  fi
fi

sudo -E python /tmp/get-pip.py >> $tmp_log
sudo -E pip install GitPython==0.3.2.RC1 >> $tmp_log

echo "[$my_hostname] Log written to: $tmp_log"

