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

class FetchVNFDsService
  ERROR_VNF_UUID_IS_MANDATORY='VNF UUID parameter is mandatory'
  ERROR_CATALOGUES_URL_NOT_FOUND='Catalogue URL not found in the ENV.'
  CATALOGUES_URL = ENV.fetch('CATALOGUES_URL', '')
  
  def self.call(vnfds)
    # vnf_uuids is mandatory
    raise ArgumentError.new(ERROR_VNF_UUID_IS_MANDATORY) if vnfds.empty?
    raise ArgumentError.new(NO_CATALOGUES_URL_DEFINED_ERROR) if CATALOGUES_URL == ''
    
    vnfs = []
    vnfds.each do |vnf|
      uri = URI(catalogue_url+'/vnfs?vendor='+vnf[:vendor]+'&name='+vnf[:name]+'&version='+vnf[:version])
      req = Net::HTTP::Get.new(uri)
      req['Accept'] = 'application/json'
      res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
      case res
      when Net::HTTPSuccess
        vnfs << JSON.parse(res.body, object_class: OpenStruct)
      else
        raise ArgumentError.new("Fetching function with UUID '#{uuid}' got #{res.value}")
      end
    end
    vnfs
  end
end
