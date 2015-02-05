Description
===========

This cookbook is used to create a rolling deployment of change within an environment by
containing sections of the environment called legs and chaining the deployment between legs
and the nodes within each leg. The concept is to reduce risk of change by trickling change
into an environment and accelerating release based on success of previous "legs". This is also
more commonly known as "canary deployment" or "blue green deployment".

    For example:
        1 -> [2,3,4] -> [5,6,7,8,9,10,11,12] -> [13 .. N]

An andon cord is available which can be set at the environment level to shut down deployment
overall OR on an individual node which will prevent progression to other legs.

    For example:
        1 -> [2,3,4] -> [5,6,7,8,9,10,11,12] -> [13 .. N]
                ^
          Andon Cord >> stop >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

        1 -> [2,3,4] -> [5,6,7,8,9,10,11,12] -> [13 .. N]
                             ^
                        Andon Cord            >> stop >>>>>>

![workflow diagram](https://raw.github.com/stathy/staticapp/master/rolling_deploy_workflow.png "Sample workflow diagram")


Requirements
============

Chef 0.11.x

Platforms
---------

The list of platforms should not be limited since the code does not access any system information or configuration
but is used internally by Chef to drive configuration change of other resources.

Chef Cookbooks
-----------------

Other cookbooks can be used with this cookbook but they are not explicitly required. A good example of useage can be seen
in the [staticapp](https://github.com/stathy/staticapp) cookbook

See __USAGE__ below.

Attributes
==========

```ruby
node['apps']['#{app name}']['desired']
node['apps']['#{app name}']['rolling_deploy']['installed']
node['apps']['#{app name}']['rolling_deploy']['leg']
node['apps']['#{app name}']['rolling_deploy']['validation_time']
node['apps']['#{app name}']['rolling_deploy']['andon_cord']
node['apps']['#{app name}']['rolling_deploy']['bootstrap_group']
```

Recipes
=======

None

USAGE
=====

There are multiple ways to trigger the identification of release. It can be done through
attributes or based on an event such as remote_file change/deployment. [staticapp](https://github.com/stathy/staticapp)
cookbook has some examples of actual use along with a sample standalone tomcat static java app.

The 'rolling_deploy_leg' resource is used to automatically asign a leg to this node on first
converge. Any node(s) bootstrapped will create a new leg. Nodes which are bootstrapped together
to be assigned the same leg can be done so by assigning the attribute :

```ruby
node['apps']['<app name>']['rolling_deploy']['bootstrap_group']
```

Otherwise, providing the attribute via override or through bootstrap mechanism will prevent
the 'rolling_deploy_leg :tag' resource to assign leg.

```ruby
rolling_deploy_leg "set leg" do
  app_name 'static'

  action :tag
end
```

Scenario 1
----------

Identification of leg readiness is performed with the 'rolling_deploy_leg' resource using action of :ready.
This will search the entire environment of which the current node is in and identify if the current leg
is ready for installation. This is based on all subsequent legs and contained nodes to have the attribute

```ruby
node['apps']['<app name>']['rolling_deploy']['installed']
```

equal to the desired resource attribute.

```ruby
rolling_deploy_leg 'install to current' do
  app_name 'static'
  desired node['apps']['static']['desired']

  action :ready
end
```

The following resources are chained to initiate deployment steps. Keep in mind, chaining demonstrated
below is not a requirement but simply one way to performing the rolling deploy. In this case, artifiacts
are not pulled across until the leg is ready, possibly optimizing resource (network, storage) useage
until absolutely needed.

```ruby
remote_file 'static' do
  path "#{node['apps']['static']['deploy_dir']}/releases/#{node['apps']['static']['desired']}.war"
  source node['apps']['static']['source']
  mode "0644"
  checksum node['apps']['static']['desired']
  action :nothing

  subscribes :create, resources('rolling_deploy_leg[install to current]'), :immediately
end
```

We then can chain the succesful execution to tag this node as successful.

```ruby
rolling_deploy_node "successful deploy" do
  app_name 'static'
  desired node['apps']['static']['desired']
  action :nothing

  subscribes :success, resources('remote_file[static]')
end
```

Scenario 2
----------

Similar to above but we prepare resources first. Perhaps resource utilization (network, storage) is
not as important as constrained maintenance window for execution (convergence).

```ruby
remote_file 'static' do
  path "#{node['apps']['static']['deploy_dir']}/releases/#{node['apps']['static']['desired']}.war"
  source node['apps']['static']['source']
  mode "0644"
  checksum node['apps']['static']['desired']
  action :nothing
end

rolling_deploy_leg 'install to current' do
  app_name 'static'
  desired node['apps']['static']['desired']
  action :nothing

  subscribes :ready, resources('remote_file[static]'), :immediately
end

# ... Additional resources for configuration, deployment and more

rolling_deploy_node "successful deploy" do
  app_name 'static'
  desired node['apps']['static']['desired']
  action :nothing

  subscribes :success, resources('http_request[validate deployment]')
end
```

We instead line up everything we need on the system, identify leg readiness, then perform execution with
minimal external dependencies as possible to configure (converge) as quickly as possible.

Scenario 3
----------

This is simply to expand on the final validation step. Ideally, chain after post configure, install validation
such as http request to make sure local system and app are actually accessible. This is strictly an example,
db queries, system check and even command or code execution for more robust validation can be performed to
ensure not only that system is configured but operating as expected to meet the service need.

```ruby
http_request "validate deployment" do
  url "http://localhost:8080/static"
# force failure of tomcat, 404 error
#  url "http://localhost:8080/fail"
  message ""
  action :get

# Decoupled from installation so it can be run on subsequent chef runs, eg. in the event of manual correction    
  only_if { File.exists?("#{node['apps']['static']['deploy_dir']}/releases/#{node['apps']['static']['desired']}.war") }
end

rolling_deploy_node "successful deploy" do
  app_name 'static'
  desired node['apps']['static']['desired']
  action :nothing

  subscribes :success, resources('http_request[validate deployment]')
end
```

Reporting and Monitoring
=====

See [rolling_deploy repo](https://github.com/stathy/rolling_deploy)

Curses based status can be retrieved using utilities in "bin" folder. These leverage a template library called 'liquid'.

    gem install liquid --no-rdoc --no-ri

Ideally, use 'watch' and pipe search output in 'json' format to deploy_monitor.rb

Some examples, rolling deployment in flight across 3 legs of varying size and completion :

    watch --differences "knife search node 'apps_static:* AND apps_static_rolling_deploy:* AND apps_static_rolling_deploy_leg:*' --format json | ruby deploy_monitor.rb"

![deployment_monitor.rb rolling](https://raw.github.com/stathy/staticapp/master/deploy_monitor_rolling.png "deploy_monitor.rb")


![deploy_monitor.rb complete](https://raw.github.com/stathy/staticapp/master/deploy_monitor_complete.png "deploy_monitor.rb")


License and Author
==================

Author:: Stathy <stathy@stathy.com>

CreatedBy:: Stathy Touloumis (<stathy@stathy.com>)

Copyright:: 2014, Stathy, Inc 

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

