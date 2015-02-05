#
# Author:: cookbooks@chef.io
# CreatedBy:: Stathy Touloumis <stathy@chef.io>
#
# Cookbook Name:: rolling_deploy
# Provider:: artifact
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

class RollingDeployArtifactError < StandardError; end

require 'chef/environment'
require 'chef/knife'
require 'chef/knife/cookbook_download'
# Temporary to accomodate CHEF-3937
require 'chef/cookbook/metadata'
require 'chef/cookbook_uploader'
require 'chef/knife/cookbook_upload'
require 'chef/knife/cookbook_create'
require 'chef/json_compat'
require 'chef'

require 'digest'
require 'fileutils'
require 'json'

action :deploy do
  if @new_resource.artifact_path.nil? || @new_resource.desired.nil? then
# Since these are data driven, it's possible we are just bootstrapping monitor node
# so handle gracefully
    Chef::Log.warn( %Q(Artifact path "#{@new_resource.artifact_path}" or desired "#{@new_resource.desired}" attribute are "nil", must be initializing ...) )

  else
# We are good so stage dat shit
    artifact_checksum = Digest::SHA256.file( @new_resource.artifact_path ).to_s
    if artifact_checksum.eql?( @new_resource.checksum ) then
# Double check to make sure the checksum of artifact on file is matched that of
# what's provided via data, should be done by consumer (recipe) but want to be sure

# Validate that the current deployment is complete, otherwise don't process build
      desired = node['apps'][@new_resource.app_name]['desired'] || 'nil'
      solr_query = <<EOF.gsub(/\s+/,' ').strip
        chef_environment:#{node.chef_environment}
        AND apps_#{@new_resource.app_name}_rolling_deploy:*
        AND apps_#{@new_resource.app_name}_rolling_deploy_installed:*
        AND apps_#{@new_resource.app_name}_rolling_deploy_leg:[1 TO *]
        NOT apps_#{@new_resource.app_name}_rolling_deploy_installed:#{desired}
        NOT name:#{node.name}
  
EOF
      Chef::Log.info( %Q(Query to check status on current deployment "#{solr_query}") )

# If we are initializing process - true
# OR if the desired app is not equal to current desired app (updated) - true
# AND the current deployment is completed (all legs) - true
      if ( @new_resource.desired != desired ) && search( :node, solr_query ).empty? then
# Search result empty which means there are no nodes currently deploying, all legs complete
        unless @new_resource.cookbook_name.nil? then
          cookbook_base = ::File.expand_path(Array(Chef::Config[:cookbook_path]).first)
          cookbook_path = ::File.join( cookbook_base, @new_resource.cookbook_name)
          if ::File.directory?( cookbook_path ) then
            Chef::Log.info( %Q(Removing old cookbook #{cookbook_path} directory") )
            FileUtils.rm_rf( cookbook_path )
          end

# If there is no knife.rb provided, use authz as client, need appropriate perms
# set to change env that this node is in.
          Chef::Config.from_file(@new_resource.knife_rb_path) unless @new_resource.knife_rb_path.nil?

# Upload new cookbook along with artifact file
          create = Chef::Knife::CookbookCreate.new
          create.config['cookbook_path'] = cookbook_path
          unless @new_resource.cookbook_version.nil? then
            create.config['version'] = @new_resource.cookbook_version
          end
          create.config['force'] = true
          create.name_args = [ @new_resource.cookbook_name ]
          create.run

# Create file for retrieval via cookbook_file resource
          FileUtils.cp_r( @new_resource.artifact_path, ::File.join( cookbook_path, '/files/default' ) )
          Chef::Log.info( %Q(Copied "#{@new_resource.artifact_path}" to "#{cookbook_path}/files/default" directory) )
  
          upload = Chef::Knife::CookbookUpload.new
          upload.config['cookbook_path'] = cookbook_path
          unless @new_resource.cookbook_version.nil? then
            ruby_meta = ::File.join(cookbook_path, 'metadata.rb')
            json_meta = ::File.join(cookbook_path, 'metadata.json')

            md = Chef::Cookbook::Metadata.new
            md.name( @new_resource.cookbook_name)
            md.from_file( ruby_meta )
            md.version( @new_resource.cookbook_version )
            ::FileUtils.rm_f( ::File.join(cookbook_path, 'metadata.rb') )
            ::File.open(json_meta, "w") do |f|
              f.write( Chef::JSONCompat.to_json_pretty(md) )
            end
            upload.config['version'] = @new_resource.cookbook_version
          end
          upload.config['force'] = true
          upload.name_args = [ @new_resource.cookbook_name ]
          upload.run
  
          unless @new_resource.cookbook_version.nil? then
            env_obj = Chef::Environment.load(node.chef_environment)
            env_obj.cookbook_versions[ @new_resource.cookbook_name ] = @new_resource.cookbook_version
            env_obj.save
          end

          @new_resource.updated_by_last_action(true)      
        end
      
      else
# Initializing, not all legs complete so no converge
        Chef::Log.info( %Q(No new deployment and not all legs complete so nothing to do ...) )
        false

      end

      env_obj = Chef::Environment.load(node.chef_environment)
# Set desired application to be installed on env level, propogate to nodes, pin cookbook if specified
      unless env_obj.override_attributes['apps'][ @new_resource.app_name ]['desired'].eql?( @new_resource.desired )
        if @new_resource.cookbook_name.nil? then
          env_obj.override_attributes['apps'][ @new_resource.app_name ]['source'] = @new_resource.artifact_path

        else
          env_obj.override_attributes['apps'][ @new_resource.app_name ]['source'] = ::File.basename( @new_resource.artifact_path )
        end

        env_obj.override_attributes['apps'][ @new_resource.app_name ]['desired'] = @new_resource.desired

        env_obj.save
        @new_resource.updated_by_last_action(true)
      end

    else
# Handle wacky shit, cuz that's how we roll
      Chef::Log.warn(<<EOF)
        Artifact checksum does not match with attribute checksum for resource, artifact tampered with, skipping ...
          artifact copied >>>>>>> "#{artifact_checksum}"
          provided to resource >> "#{@new_resource.checksum}"

EOF
      false
  
    end
  end
end

def load_current_resource
  @current_resource = Chef::Resource::RollingDeployArtifact.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource
end


