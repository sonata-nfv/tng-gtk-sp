## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).
# encoding: utf-8
require 'sinatra/base'
require 'rack-timeout-puma'
require 'active_record'
%w{ controllers models services }.each do |dir|
  path = File.expand_path(File.join(File.dirname(__FILE__), dir))
  $LOAD_PATH.unshift(path)
end
require 'tng/gtk/utils/application_controller'
require 'requests_controller'
require 'policies_controller'
require 'pings_controller'
require 'root_controller'
require 'records_controller'
require 'slices_controller'
require 'request'

ENV['RACK_ENV'] ||= 'production'

# from https://stackoverflow.com/questions/41400202/replacing-activerecordconnectionadaptersconnectionmanagement-in-activerecord
class ConnectionManagement
  def initialize(app)
    @app = app
  end

  def call(env)
    testing = env['rack.test']

    status, headers, body = @app.call(env)
    proxy = ::Rack::BodyProxy.new(body) do
      ActiveRecord::Base.clear_active_connections! unless testing
    end
    [status, headers, proxy]
  rescue Exception
    ActiveRecord::Base.clear_active_connections! unless testing
    raise
  end
end

use ConnectionManagement
=begin
ActiveRecord::Base.establish_connection(
  :adapter => 'postgresql',
  :host =>  'son-postgres', #'pre-int-sp-ath.5gtango.eu',
  :database => 'gatekeeper',
  :password => 'sonata',
  :username => 'sonatatest',
  :port => 5432,
  :pool => 128,
  )
=end
# from https://github.com/keyme/rack-timeout-puma
#use Rack::Timeout
#use Rack::Timeout::Puma
#use ActiveRecord::Rack::ConnectionManagement # this seems not to be working anynore
STDERR.puts "ActiveRecord::Base.configurations=:#{ActiveRecord::Base.configurations[ENV['RACK_ENV'].to_sym]}"
map('/pings')    { run PingsController }
map('/policies') { run PoliciesController } 
map('/records')  { run RecordsController } 
map('/requests') { run RequestsController } 
map('/slices')   { run SlicesController}
map('/')         { run RootController }
