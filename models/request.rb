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
require 'json'
require 'sinatra/activerecord'

class Request < ActiveRecord::Base
  self.establish_connection(
    adapter:  "postgresql",
    host:     ENV.fetch('DATABASE_HOST','son-postgres'),
    port:     ENV.fetch('DATABASE_PORT', 5432),
    username: ENV.fetch('POSTGRES_USER', 'postgres'),
    password: ENV.fetch('POSTGRES_PASSWORD', 'sonatatest'),
    database: ENV.fetch('DATABASE_NAME', 'gatekeeper'),
    pool:     64,
    timeout:  10000,
    encoding: 'unicode'
  )
  STDERR.puts ">>> Request is Connected to #{Request.connection.current_database}"
  STDERR.puts ">>> Request.configurations=:#{Request.configurations}"
  STDERR.puts ">>> Request.connection_pool.stat=#{Request.connection_pool.stat}"
  serialize :mapping
  
  def vim_from_json
    begin
      JSON.parse self[:vim_list]
    rescue
      []
    end
  end
end
