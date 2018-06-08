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

class FetchNSDService  
  ERROR_NS_UUID_IS_MANDATORY='Network Service UUID parameter is mandatory'
  NO_CATALOGUE_URL_DEFINED_ERROR='The CATALOGUE_URL ENV variable needs to defined and pointing to the Catalogue where to fetch services'
  CATALOGUE_URL = ENV.fetch('CATALOGUE_URL', '')
  
  def self.call(service_uuid)
    msg=self.name+'#'+__method__.to_s
    STDERR.puts "#{msg}: service_uuid=#{service_uuid}"
    raise ArgumentError.new(NO_CATALOGUE_URL_DEFINED_ERROR) if CATALOGUE_URL == ''
    raise ArgumentError.new(ERROR_NS_UUID_IS_MANDATORY) if service_uuid.empty?
    
    uri = URI(catalogue_url+'/network-services/'+service_uuid)
    req = Net::HTTP::Get.new(uri)
    req['Accept'] = 'application/json' #req['Content-Type'] = 
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    case res
    when Net::HTTPSuccess
      service = JSON.parse(res.body, object_class: OpenStruct)
      STDERR.puts "#{msg}: nsd=#{service[:nsd]}"
      service
    else
      raise ArgumentError.new("Fetching service with UUID '#{service_uuid}' got #{res.value}")
    end
  end
end


