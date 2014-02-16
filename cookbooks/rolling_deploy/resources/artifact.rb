#
# Author:: cookbooks@opscode.com
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: rolling_deploy
# Resource:: artifact
#
# Copyright:: 2013, Opscode, Inc <legal@opscode.com>
#

actions :deploy, :complete
default_action :deploy

attribute :name,          :kind_of => String, :name_attribute => true
attribute :app_name,      :kind_of => String, :required => true

# holding area for newly created artifact
attribute :artifact_path, :kind_of => String, :required => true
attribute :checksum,      :kind_of => String, :required => true
attribute :desired,       :kind_of => String, :required => true

# holding area where optional artifact cookbook is created, name and version
attribute :cookbook_name, :kind_of => String
attribute :cookbook_version, :kind_of => String

#If not knife_rp_path is passed, will default authz to client
attribute :knife_rb_path, :kind_of => String, :default => nil

def initialize(*args)
  super
  @desired = @checksum if @desired.nil?
end
