#!/bin/bash

watch --differences "knife search node 'apps_${1}:* AND apps_${1}_rolling_deploy:* AND apps_${1}_rolling_deploy_leg:*' --format json | ruby deploy_monitor.rb"

