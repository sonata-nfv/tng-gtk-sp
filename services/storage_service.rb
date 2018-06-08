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
require 'pg'
require 'activerecord'
require 'sinatra/activerecord'
require 'json'

class StorageService  
  ERROR_VNFS_ARE_MANDATORY='VNFs parameter is mandatory'
  ERROR_DATABASE_URL_NOT_FOUND='VNF Catalogue URL not found in the ENV.'
  
  postgres_url = ENV['DATABASE_URL']
  raise Exception.new(ERROR_DATABASE_URL_NOT_FOUND) if postgres_url.to_s.empty?
  ActiveRecord::Base.establish_connection(postgres_url)

  # Set up database tables and columns
  ActiveRecord::Schema.define do
    create_table :owners, force: true do |t|
      t.string :name
    end
    create_table :pets, force: true do |t|
      t.string :name
      t.references :owner
    end
  end
  
  def initialize
    
  end
  
  def self.call(params)
    ENV POSTGRES_PASSWORD sonata
    ENV POSTGRES_USER sonatatest
    ENV DATABASE_HOST postgres
    ENV DATABASE_PORT 5432
    ENV MQSERVER amqp://guest:guest@broker:5672
    ENV CATALOGUES_URL http://sp.int.sonata-nfv.eu:4002/catalogues
    # Connect to database.
    uri = URI.parse(ENV['DATABASE_URL'])
    postgres = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
  end
end
