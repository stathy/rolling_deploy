#
# Author:: cookbooks@opscode.com
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: rolling_deploy
# Resource:: leg
#
# Copyright:: 2013, Opscode, Inc <legal@opscode.com>
#

actions :tag, :ready
default_action :tag

attribute :name,        :kind_of => String, :name_attribute => true
attribute :app_name,    :kind_of => String, :required => true
attribute :desired,    :kind_of => String, :required => true
