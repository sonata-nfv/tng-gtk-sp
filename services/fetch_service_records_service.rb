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
require 'tng/gtk/utils/logger'
require 'tng/gtk/utils/fetch'

class FetchServiceRecordsService < Tng::Gtk::Utils::Fetch
  NO_REPOSITORY_URL_DEFINED_ERROR='The REPOSITORY_URL ENV variable needs to defined and pointing to the Repository where to fetch records'
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  
  REPOSITORY_URL = ENV.fetch('REPOSITORY_URL', '')
  if REPOSITORY_URL == ''
    LOGGER.error(component:LOGGED_COMPONENT, operation:'fetching REPOSITORY_URL ENV variable', message:NO_REPOSITORY_URL_DEFINED_ERROR)
    raise ArgumentError.new(NO_REPOSITORY_URL_DEFINED_ERROR) 
  end
  self.site=REPOSITORY_URL+'/nsrs'
  LOGGER.info(component:LOGGED_COMPONENT, operation:'site definition', message:"self.site=#{self.site}")
  
  def self.call(params)
    msg=self.name+'#'+__method__.to_s
    service_records = super
    case service_records
    when Hash
      return enrich_one(service_records)
    when Array
      enriched = []
      service_records.each { |record| enriched << enrich_one(record)}
      return enriched
    else
      service_records
    end
  end
  
  private
  def self.enrich_one(record)
    msg=self.name+'#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:'.'+__method__.to_s, message:"record=#{record}")
    request = Request.where("instance_uuid = ? AND request_type = 'CREATE_SERVICE'", record[:uuid]).as_json
    LOGGER.debug(component:LOGGED_COMPONENT, operation:'.'+__method__.to_s, message:"request=#{request}")
    return record if request.empty?
    LOGGER.debug(component:LOGGED_COMPONENT, operation:'.'+__method__.to_s, message:"request name = '#{request[0]['name']}'")
    record[:instance_name] = request[0]['name']
    record
  end
end
