#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: rolling_deploy
# Resource:: integrate_db
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

actions :search_set_db!, :configure_slave, :query_sync_point!
default_action :search_set_db!

attribute :name,                :kind_of => String, :name_attribute => true
attribute :app_name,            :kind_of => String, :required => true
attribute :db_platform,         :kind_of => String, :required => true, :regex => /^mysql$/
attribute :qry_type,            :kind_of => String, :default => 'single', :regex => /^master|slave|single$/
attribute :allow_merged_tier,   :kind_of => [ TrueClass, FalseClass ], :default => true
attribute :raise_empty,         :kind_of => [ TrueClass, FalseClass ], :default => true
attribute :environment,         :kind_of => String, :default => node.chef_environment
attribute :solr_query,          :kind_of => String, :default => nil

#attribute :return_val,    :kind_of => String, :default => 'ip', :regex => /^ip|fqdn$/i
#attribute :solr_query,    :kind_of => String, :default => %Q()
