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
require 'net/http'
require 'ostruct'
require 'json'
require 'yaml'
require_relative '../models/request'
require 'tng/gtk/utils/logger'

class ProcessRequestBase  
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  
  def self.search(page_number, page_size, strategies)
    msg='.'+__method__.to_s
    
    begin
      requests = Request.order(updated_at: :desc).limit(page_size).offset(page_number).as_json
    ensure
      Request.clear_active_connections!
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"requests=#{requests}")
    requests
    #return requests if requests.empty?
    #enriched = []
    
    #requests.each do |request|
    #  LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"request=#{request}\nstrategy=#{strategies[request['request_type'].to_sym]}")
    #  enriched << strategies[request['request_type'].to_sym].enrich_one(request)
    #end
  end
  
  def self.find(uuid, strategies)
    begin
      request = Request.find(uuid).as_json
    ensure
      Request.clear_active_connections!
    end
    return request if request.empty?
    strategies[request[:request_type].to_sym].enrich_one(request)
  end
  
  def self.descendants
    ObjectSpace.each_object(Class).select { |klass| klass < self }    
  end
  
  def camelize(s)
    s.split("_").each {|ss| ss.capitalize! }.join("")  
  end
  
  private
  
  def self.valid_uuid?(uuid)
    uuid.match /[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}/
    uuid == $&
  end
  
end