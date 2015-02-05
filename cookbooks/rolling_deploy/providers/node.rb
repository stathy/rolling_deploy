#
# Author:: cookbooks@chef.io
# CreatedBy:: Stathy Touloumis <stathy@chef.io>
#
# Cookbook Name:: rolling_deploy
# Provider:: node
#
# Copyright:: 2014, Stathy, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
#
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class RollingDeployNodeError < StandardError; end

action :success do

  if node['apps'][@new_resource.app_name]['rolling_deploy']['installed'].eql?(@new_resource.desired) then
    Chef::Log.info( %Q(node desired equals installed, not updating ...) )

  else
    node.set['apps'][@new_resource.app_name]['rolling_deploy']['installed'] = @new_resource.desired
    node.set['apps'][@new_resource.app_name]['rolling_deploy']['validation_time'] = Time.now.localtime()
    @new_resource.updated_by_last_action(true)
  
    rd_node_attr = node['apps'][@new_resource.app_name]['rolling_deploy']
    Chef::Log.info(<<EOF).to_s.strip
      Successful installation, setting attributes
      {
        installed:"#{rd_node_attr['installed']}"
        validation_time:"#{rd_node_attr['validation_time']}"        
      }
EOF
  end

end

def load_current_resource
  @current_resource = Chef::Resource::RollingDeployNode.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource
end

