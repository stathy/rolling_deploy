#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: rolling_deploy
# Provider:: integrate_db
#
# Copyright:: 2013, Opscode, Inc <legal@opscode.com>
#

class RollingDeployIntegrateDbError < StandardError; end

action :search_set_db! do
  dbm = nil
  name = @new_resource.app_name
  env = @new_resource.environment

  if @new_resource.allow_merged_tier && node['apps'][ name ]['tier'].include?('db') && node['apps'][ name ]['tier'].include?('app')
    dbm = node
    node.save

  else
    solr_qry = @new_resource.solr_query || <<SOLR
      chef_environment:#{env}
        AND apps:*
        AND apps_#{name}:*
        AND apps_#{name}_tier:*
        AND apps_#{name}_tier:db
        AND #{@new_resource.db_platform}:*
SOLR
    if @new_resource.qry_type == 'single' then
      solr_qry += <<SOLR
        NOT #{@new_resource.db_platform}_replication:*
        NOT #{@new_resource.db_platform}_replication_type:*
SOLR

    else
      solr_qry += <<SOLR
        AND #{@new_resource.db_platform}_replication:*
        AND #{@new_resource.db_platform}_replication_type:*
        AND #{@new_resource.db_platform}_replication_type:#{@new_resource.qry_type}
SOLR
    end
    solr_qry.gsub!(/\s+/,' ').strip

    Chef::Log.info( %Q(DB '#{@new_resource.qry_type}' solr query '#{solr_qry}') )

    dbm = search("node", solr_qry ).last
#    dbm = search("node", @new_resource.solr_query).last

  end

  if @new_resource.raise_empty && dbm.nil?
    raise( %Q(Unable to find database host where attribute node['apps']['#{@new_resource.app_name}']['tier'] contains 'db') )

  else
    server_ip = begin
      if dbm['mysql'].has_key?('bind_address') && dbm['mysql']['bind_address'] !~  /^0\.0\.0\.0$/ then
        dbm['mysql']['bind_address']

      elsif dbm.has_key?('ipaddress_internal')
        dbm['ipaddress_internal']

      elsif dbm.has_key?('ec2')
        dbm['ec2']['public_ipv4']

      elsif ! dbm['ipaddress'].nil?
        dbm['ipaddress']

      else
        dbm['fqdn']
      end
    end

    dbm_info = {
      'fqdn'      => dbm['fqdn'],
      'server_ip' => server_ip,
    }
    if @new_resource.qry_type.match(/master|slave/) then
      dbm_info['log_file'] = dbm['mysql']['replication']['log_file']
      dbm_info['position'] = dbm['mysql']['replication']['position']
    end
    node.run_state['dbapp_orchestrate_db::dbm'] = dbm_info

    @new_resource.updated_by_last_action(true)

  end

end

action :configure_slave do
  dbh_of_root = begin
    connection = ::Mysql.new(
      'localhost',
      'root',
      node['mysql']['server_root_password'],
      nil,
      node['mysql']['port']
    )
    connection.set_server_option ::Mysql::OPTION_MULTI_STATEMENTS_ON
    connection
  end

  rolling_deploy_integrate_db "dbapp_orchestrate_db - search for master" do
    app_name new_resource.app_name
    db_platform new_resource.db_platform
    action :nothing
    qry_type 'master'
  
    retries node['mysql']['search']['retries']
    retry_delay node['mysql']['search']['retry_delay']
  
    only_if { node.run_state['dbapp_orchestrate_db::dbm'].nil? }
  end.run_action(:search_set_db!)

  bind_vars = node.run_state['dbapp_orchestrate_db::dbm']
  Chef::Log.warn( %Q(Set sync info for slave >>>#{bind_vars.to_yaml}<<<) )
  
  unless (
    node['mysql']['replication'].has_key?('log_file') &&
    node['mysql']['replication']['log_file'].match(bind_vars['log_file']) &&
    node['mysql']['replication']['position'].match(bind_vars['position'])
  ) then
    set_master_sql = <<SQL
      STOP SLAVE ;
  
      CHANGE MASTER TO
        MASTER_HOST = '#{bind_vars["server_ip"]}',
        MASTER_USER = 'repl',
        MASTER_PASSWORD = '#{node["mysql"]["server_repl_password"]}',
        MASTER_LOG_FILE = '#{bind_vars["log_file"]}',
        MASTER_LOG_POS = #{bind_vars["position"]} ;
  
      START SLAVE ;
SQL
  
    Chef::Log.debug("Performing query [#{set_master_sql}]")
      dbh_of_root.query( set_master_sql )

    node.normal['mysql']['replication']['log_file'] = bind_vars['log_file']
    node.normal['mysql']['replication']['position'] = bind_vars['position']
    @new_resource.updated_by_last_action(true)
  
    dbh_of_root.close

  end
end

action :query_sync_point! do
  dbh_of_root = begin
    connection = ::Mysql.new(
      'localhost',
      'root',
      node['mysql']['server_root_password'],
      nil,
      node['mysql']['port']
    )
    connection.set_server_option ::Mysql::OPTION_MULTI_STATEMENTS_ON
    connection
  end

  dbh_of_root.query("FLUSH TABLES WITH READ LOCK")

  obtain_sync_sql = <<SQL
    SHOW MASTER STATUS
SQL

  Chef::Log.warn("Performing query [#{obtain_sync_sql}]")

  rslt = dbh_of_root.query( obtain_sync_sql )
  data = rslt.fetch_row || raise( %Q(Not configured for replication, please see database docs) )
  dbh_of_root.close

  Chef::Log.info( %Q(Obtained sync info for slaves '#{(data[0,1]).to_s}') )
  node.normal['mysql']['replication']['log_file'] = data[0]
  node.normal['mysql']['replication']['position'] = data[1]

  @new_resource.updated_by_last_action(true)
end


def load_current_resource
  Gem.clear_paths
  require 'mysql'

  @current_resource = Chef::Resource::RollingDeployIntegrateDb.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  @current_resource
end


__END__

