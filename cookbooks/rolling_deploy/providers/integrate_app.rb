#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: rolling_deploy
# Provider:: orchestrate_lb
#
# Copyright:: 2014, Chef, Inc
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

class IntegrateAppError < StandardError; end

action :search_set_lb! do
  name = @new_resource.app_name
  env = @new_resource.environment

  solr_qry = @new_resource.solr_query || <<SOLR.gsub(/\s+/,' ').strip
    chef_environment:#{env}
      AND apps:*
      AND apps_#{name}:*
      AND apps_#{name}_tier:*
      AND apps_#{name}_tier:app
      NOT name:#{node.name}
SOLR
  Chef::Log.info( %Q(APP solr query '#{solr_qry}') )

  pool_members = search("node", solr_qry)
  if @new_resource.allow_merged_tier && node['apps'][ name ]['tier'].include?('app')
    pool_members << node
  end

  if @new_resource.raise_empty && pool_members.empty?
    node.save
    raise( %Q(Unable to find haproxy member whose node attribute node['apps'][#{name}]['tier'] is 'app') )

  else
    pool_members.map! do |member|
      server_ip = begin
        if member.attribute?('ipaddress_internal')
          member['ipaddress_internal']

       elsif member.attribute?('cloud')
          if node.attribute?('cloud') && (member['cloud']['provider'] == node['cloud']['provider'])
             member['cloud']['local_ipv4']
          else
            member['cloud']['public_ipv4']
          end

        else
          member['ipaddress']

        end
      end
      { :ipaddress => server_ip, :hostname => member['hostname'] }
    end

    Chef::Log.info( %Q(Pool members for haproxy "#{pool_members.to_s}") )
    node.run_state['dbapp_integrate_app::members'] = pool_members

  end

end

def load_current_resource
  Gem.clear_paths
  require 'mysql'

  @current_resource = Chef::Resource::RollingDeployIntegrateApp.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  @current_resource
end

