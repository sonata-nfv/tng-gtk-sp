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

class FetchLicenseService < Tng::Gtk::Utils::Fetch
  SLA_MNGR_URL = ENV.fetch('SLA_MNGR_URL', '')
  NO_SLA_MNGR_URL_DEFINED_ERROR='The SLA_MNGR_URL ENV variable needs to defined and pointing to the SLA Manager'  
  if SLA_MNGR_URL == ''
    LOGGER.error(component:'FetchLicenseService', operation:'fetching SLA_MNGR_URL ENV variable', message:NO_SLA_MNGR_URL_DEFINED_ERROR)
    raise ArgumentError.new(NO_SLA_MNGR_URL_DEFINED_ERROR) 
  end  
  # curl GET http://localhost:8080/tng-sla-mgmt/api/slas/v1/licenses/status/{sla_uuid}/{ns_uuid}
  self.site=SLA_MNGR_URL+'/licenses'
  def self.call(service_uuid, sla_uuid)
    msg=self.name+'#'+__method__.to_s
    began_at=Time.now.utc
    LOGGER.info(start_stop: 'START', component:self.name, operation:msg, message:"Checking license status: service_uuid=#{service_uuid} sla_uuid=#{sla_uuid}")
    
    uri = URI.parse("#{self.site}/status/#{sla_uuid}/#{service_uuid}")
    request = Net::HTTP::Get.new(uri)
    request['content-type'] = 'application/json'
    response = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(request)}
    LOGGER.debug(component:self.name, operation:msg, message:"response=#{response.inspect}")
    case response
    when Net::HTTPSuccess
      #{ "current_instances": "0", "allowed_instances": "20", "allowed_to_instantiate": "false",
      #  "license_type": "private", "license_status": "test", "license_expiration_date": "2020-12-01T00:00:00Z"}
      body = response.read_body
      return JSON.parse(body, quirks_mode: true, symbolize_names: true)
    when Net::HTTPNotFound
      LOGGER.debug(start_stop: 'STOP', component:self.name, operation:msg, message:"body=#{body}", status:'404', time_elapsed: Time.now.utc - began_at)
      return ''
    else
      LOGGER.error(start_stop: 'STOP', component:self.name, operation:msg, message:"#{response.message}", status:'404', time_elapsed: Time.now.utc - began_at)
      return nil
    end
  end
  def self.buy(service_uuid, sla_uuid)
    msg='#'+__method__.to_s
    began_at=Time.now.utc
    LOGGER.info(start_stop: 'START', component:self.name, operation:msg, message:"Buying license: service_uuid=#{service_uuid} sla_uuid=#{sla_uuid}")
    # curl -X POST -H "Content-type:application/x-www-form-urlencoded" -d "ns_uuid=<>&sla_uuid=<>" http://localhost:8080/tng-sla-mgmt/api/slas/v1/licenses/buy
    uri = URI.parse("#{self.site}/buy")
    response = Net::HTTP.post_form(uri, 'ns_uuid' => service_uuid, 'sla_uuid' => sla_uuid)
    LOGGER.debug(component:self.name, operation:msg, message:"response=#{response.inspect}")
    case response
    when Net::HTTPSuccess
      body = response.read_body
      return JSON.parse(body, quirks_mode: true, symbolize_names: true)
    when Net::HTTPNotFound
      LOGGER.debug(start_stop: 'STOP', component:self.name, operation:msg, message:"body=#{body}", status:'404', time_elapsed: Time.now.utc - began_at)
      return ''
    else
      LOGGER.error(start_stop: 'STOP', component:self.name, operation:msg, message:"#{response.message}", status:'404', time_elapsed: Time.now.utc - began_at)
      return nil
    end
  end
end
