#
# Author:: cookbooks@opscode.com
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: rolling_deploy
# Provider:: node
#
# Copyright:: 2013, Opscode, Inc <legal@opscode.com>
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

