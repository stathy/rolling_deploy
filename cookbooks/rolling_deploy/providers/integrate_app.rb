#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: rolling_deploy
# Provider:: orchestrate_lb
#
# Copyright:: 2013, Opscode, Inc <legal@opscode.com>
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

