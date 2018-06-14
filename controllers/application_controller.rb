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
require 'sinatra/config_file'
require 'sinatra/cross_origin'
require 'logger'
#require 'sinatra/logger'
require 'sinatra/activerecord'

class ApplicationController < Sinatra::Base
  register Sinatra::ConfigFile
  register Sinatra::CrossOrigin
  #register Sinatra::Logger

  msg = self.name
  LOGGER_LEVEL= ENV.fetch('LOGGER_LEVEL', 'info')
  set :began_at, Time.now.utc
  set :bind, '0.0.0.0'
  set :environments, %w(development pre-int integration demo qualification staging)
  set :environment, ENV.fetch('RACK_ENV', :development)
  enable :cross_origin
  enable :logging
  set :logger, Logger.new(STDERR)
  set :logger_level, LOGGER_LEVEL.to_sym
  
  #The environment variable DATABASE_URL should be in the following format:
  # => postgres://{user}:{password}@{host}:{port}/path
  configure :development, :'pre-int', :integration, :demo, :qualification, :staging do
  	db = URI.parse(ENV['DATABASE_URL'] || 'postgresql://localhost:5432/gatekeeper')

  	ActiveRecord::Base.establish_connection(
  			:adapter => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
  			:host     => db.host,
  			:username => db.user,
  			:password => db.password,
  			:database => db.path[1..-1],
  			:encoding => 'utf8'
  	)
  end
end