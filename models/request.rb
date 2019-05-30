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
    checkout_timeout: 30,
    encoding: 'unicode'
  )
  serialize :mapping
  serialize :blacklist
  serialize :egresses
  serialize :ingresses
  
  def vim_from_json
    begin
      JSON.parse self[:vim_list]
    rescue
      []
    end
  end
  
  def from_json(field)
    begin
      JSON.parse(field)
    rescue
      []
    end
  end
  
  def as_json
    {
        blacklist: from_json(self[:blacklist]),
        callback: self[:callback],
        created_at: self[:created_at],
        vim_list: vim_from_json,
        customer_email: self[:customer_email],
        customer_name: self[:customer_name],
        description: self[:description],
        duration: self[:duration],
        egresses: from_json(self[:egresses]),
        error: self[:error],
        flavor: self[:flavor],
        function_uuids: self[:function_uuids],
        id: self[:id],
        ingresses: from_json(self[:ingresses]),
        instance_uuid: self[:instance_uuid],
        mapping: from_json(self[:mapping]),
        name: self[:name],
        number_of_instances: self[:number_of_instances],
        request_type: self[:request_type],
        scaling_type: self[:scaling_type],
        service_uuid: self[:service_uuid],
        #"service": {
        #    "name": "communication-pilot",
        #    "uuid": "0ebd49da-9db2-4418-8211-190a6d74ed2d",
        #    "vendor": "quobis",
        #    "version": "0.2"
        #},
        sla_id: self[:sla_id] ||= '',
        status: self[:status],
        updated_at: self[:updated_at],
        vim_uuid: self[:vim_uuid] ||= '',
        vnf_uuid: self[:vnf_uuid] ||= '',
        vnfd_uuid: self[:vnfd_uuid] ||= ''
    }
  end
end
