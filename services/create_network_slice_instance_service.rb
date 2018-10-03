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
require 'uri'
require 'json'

class CreateNetworkSliceInstanceService 
  NO_SLM_URL_DEFINED_ERROR='The SLM_URL ENV variable needs to be defined and pointing to the Slice Manager component, where to request new Network Slice instances'
  SLM_URL = ENV.fetch('SLM_URL', '')
  if SLM_URL == ''
    STDERR.puts "%s - %s: %s" % [Time.now.utc.to_s, self.name, NO_SLM_URL_DEFINED_ERROR]
    raise ArgumentError.new(NO_SLM_URL_DEFINED_ERROR) 
  end
  # POST http://tng-slice-mngr:5998/api/nsilcm/v1/nsi, with body {...}
  @@site=SLM_URL+'/nsilcm/v1/nsi'
  STDERR.puts "%s - %s: %s" % [Time.now.utc.to_s, self.name, "@@site=#{@@site}"]
  
  def self.call(params)
    msg=self.name+'#'+__method__.to_s
    STDERR.puts "#{msg}: params=#{params} site=#{@@site}"
    uri = URI.parse(@@site)

    # Create the HTTP objects
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri, {'Content-Type': 'text/json'})
    request.body = params.to_json

    # Send the request
    begin
      response = http.request(request)
      STDERR.puts "#{msg}: response=#{response}"
      case response
      when Net::HTTPSuccess, Net::HTTPCreated
        body = response.body
        STDERR.puts "#{msg}: #{response.code} body=#{body}"
        return JSON.parse(body, quirks_mode: true, symbolize_names: true)
      else
        return {error: "#{response.message}"}
      end
    rescue Exception => e
      STDERR.puts "%s - %s: %s" % [Time.now.utc.to_s, msg, e.message]
    end
    nil
  end
end


