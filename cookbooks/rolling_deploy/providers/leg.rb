#
# Author:: cookbooks@chef.io
# CreatedBy:: Stathy Touloumis <stathy@chef.io>
#
# Cookbook Name:: rolling_deploy
# Provider:: leg
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

class RollingDeployLegError < StandardError; end

action :tag do

  rd_boot_attr = node['apps'][@new_resource.app_name]['rolling_deploy']['bootstrap_group']
  rd_leg_attr = node['apps'][@new_resource.app_name]['rolling_deploy']['leg']

  if rd_leg_attr.nil? then
# Only set the leg if it's not initialized (0,n), 0 being disabled
    solr_query = <<EOF.gsub(/\s+/,' ').strip
      chef_environment:#{node.chef_environment}
      AND apps_#{@new_resource.app_name}_rolling_deploy_bootstrap_group:{0 TO #{rd_boot_attr}}
EOF
    leg_idx = search( :node, solr_query ).map { |i| i['apps'][@new_resource.app_name]['rolling_deploy']['leg'] }
    leg_cnt = node.set['apps'][@new_resource.app_name]['rolling_deploy']['leg'] = leg_idx.compact.sort.last.to_i + 1

    @new_resource.updated_by_last_action(true)
    node.save

    Chef::Log.info( %Q(Leg index number is "#{leg_cnt}") )
  
  else
    false

  end

end

action :ready do

  if @new_resource.desired.eql?( node['apps'][@new_resource.app_name]['rolling_deploy']['installed'] )
# If we don't have a new app to install, don't bother checking if we're on the right leg
    Chef::Log.info( %Q(rd desired and installed are equal, skipping ...) )
    false

  elsif node['apps'][@new_resource.app_name]['rolling_deploy']['leg'].eql?(0) then
# Leg '0' reserved for 'disabled' nodes in leg
    Chef::Log.info( %Q(Node deployment is disabled, removed from legs with value "0") )
    false

  else
    Chef::Log.info( %Q(rd desired and installed are not identical, checking if leg is ready.) )

    rd_leg_attr = node['apps'][@new_resource.app_name]['rolling_deploy']['leg']
    solr_query = <<EOF.gsub(/\s+/,' ').strip
      chef_environment:#{node.chef_environment}
        AND ( (
            apps_#{@new_resource.app_name}_rolling_deploy_leg:{0 TO #{rd_leg_attr}}
            AND apps_#{@new_resource.app_name}_rolling_deploy_andon_cord:true
          ) OR (
            apps_#{@new_resource.app_name}_rolling_deploy_leg:{0 TO #{rd_leg_attr}}
            NOT apps_#{@new_resource.app_name}_rolling_deploy_installed:#{@new_resource.desired}
          ) )
EOF

    if rd_leg_attr == 1 then
# If we are on first leg, then by default we should attempt install
      Chef::Log.info( %Q(On leg "1" which is always ready.) )
      @new_resource.updated_by_last_action(true)

    elsif search( :node, solr_query ).empty? then
# If we are NOT on first leg, AND the current app version is completely installed on previous legs, install on this leg and node
      Chef::Log.info( %Q(rd install leg query "#{solr_query}"))
      Chef::Log.info( %Q(env search returned empty, leg is ready.) )
      @new_resource.updated_by_last_action(true)

    else
# Improve the rate at which rolling_deploy occurs, retry if previous legs not complete, 2x 7s
      Chef::Log.info( %Q(rd install leg query "#{solr_query}"))

      2.times do
          Chef::Log.info( %Q(rd search returned results, previous leg deploy still in progress ...) )
        sleep 7

        if search( :node, solr_query ).empty? then
          Chef::Log.info( %Q(env search returned empty, leg is ready.) )
          @new_resource.updated_by_last_action(true)
          break

        else
          false

        end
      end
    end

  end
end

def load_current_resource
  @current_resource = Chef::Resource::RollingDeployLeg.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource
end

