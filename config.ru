# This file is used by Rack-based servers to start the application.

require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'

#use Prometheus::Middleware::Collector
use Prometheus::Middleware::Exporter

require ::File.expand_path('../config/environment',  __FILE__)
run Zammad::Application

# set config to do no self notification
Rails.configuration.webserver_is_active = true
