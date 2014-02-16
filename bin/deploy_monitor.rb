#!/usr/bin/env ruby
#

require 'json'
require 'chef/environment'
require 'chef/knife'
require 'chef/node'
require 'chef'
require 'liquid'
require 'time'

app_name = 'static'

cur_dir = File.dirname(__FILE__)

rep = Liquid::Template.parse( File.read("#{cur_dir}/deploy_monitor.lqd") )
node_data = JSON.load(ARGF)
rep_data = []

unless node_data['rows'].empty? then

# Normalize across versions
  node_data['rows'].each do |r|
    n = {}

    n['name'] = ( r.name[0,18] + '..' )
    n['apps'] = []

    r_a = r.apps[ app_name ]
# For now just take a single app, eventually loop through all

    n['apps'] << {}
    a = n['apps'][0]

    a['name'] = app_name
    a['leg'] = r_a['rolling_deploy']['leg']
    a['desired'] = r_a['desired']
    a['installed'] = r_a['rolling_deploy']['installed']

    if r_a['rolling_deploy']['validation_time'].nil?
      a['installed_on'] = ' '
    else
      t = Time.parse(r_a['rolling_deploy']['validation_time'])
      a['installed_on'] = t.strftime('%b %d %H:%M:%S %Z')
    end

    n['checkin'] = Time.at(r.ohai_time.to_f).strftime('%H:%M:%S')

    if a['leg'] !~ /blue|green/ && a['leg'].to_i == 0 then
      a['rd_status'] = 'DISABLED'
    elsif a['desired'].eql?( a['installed'] )
      a['rd_status'] = 'INSTALLED'
    else
      a['rd_status'] = 'DEPLOYING'
    end

    rep_data << n
  end
  
  node_data = nil

#sor by leg, then node name
  rep_data.sort_by! do |n|
    [ n['apps'][0]['leg'].to_s, n['name'] ]
  end

#Format for output
  rep_data.each do |n|
    n['name'] = n['name'].to_s.center(24)
    n['checkin'] = n['checkin'].center(12)
  
    n['apps'].each do |a|
      a['name'] = ( a['name'] + %Q( v"#{a['desired'][0,14]}..") ).center(30)
      a['leg'] = a['leg'].to_s.center(7)
      a['installed_on'] = a['installed_on'].center(21)
      a['rd_status'] = a['rd_status'].center(14)
    end
  end

end

puts rep.render( { 'nodes' => rep_data } )

__END__
## Report model
------------------------------------------------------------------------------------------------------------------------
|           NODE         |         APP and VERSION      |  LEG  |    STATUS    |     INSTALLED AT    |  CHECK-IN  |
------------------------------------------------------------------------------------------------------------------------
|  java-a1-a81259cef8..  |  static v"037b74d76e9e27.."  |   1   |  INSTALLED   | Mar 01 14:06:02 CST |  14:09:53  |
------------------------------------------------------------------------------------------------------------------------
|  java-a2-a81259cef8..  |  static v"037b74d76e9e27.."  |   2   |  INSTALLED   | Mar 01 14:06:16 CST |  14:10:03  |
------------------------------------------------------------------------------------------------------------------------
|  java-a3-a81259cef8..  |  static v"037b74d76e9e27.."  |   3   |  INSTALLED   | Mar 01 14:06:34 CST |  14:10:00  |
------------------------------------------------------------------------------------------------------------------------