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

class ProcessRequestService  
  ERROR_VNFS_ARE_MANDATORY='VNFs parameter is mandatory'
  ERROR_VNF_CATALOGUES_URL_NOT_FOUND='VNF Catalogue URL not found in the ENV.'

  def self.call(params)
    msg=self.name+'.'+__method__.to_s
    request_type = params.key?(:request_type) ? params.delete(:request_type) : 'CREATE_SERVICE'
    STDERR.puts "#{msg}: params=#{params}"
    
    begin
      return send(request_type.downcase.to_sym, params)
    rescue NoMethodError => e
      raise ArgumentError.new("'#{request_type}' is not valid as a request type")
    end
  end
  
  private
  def self.create_service(params)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: params=#{params}"
    begin
      stored_service = FetchNSDService.call(uuid: params[:uuid])
      stored_functions = FetchVNFDsService.call(stored_service[:nsd][:network_functions])
      params[:began_at] = Time.now.utc
      instantiation_request = Request.create(params)
      user_data = FetchUserDataService.call( params[:customer_uuid], stored_service[:username], params[:sla_id])
      message = build_message(stored_service, stored_functions, params[:egresses], params[:ingresses], user_data)
      STDERR.puts "#{msg}: message=\n#{message}"
      publishing_response = MessagePublishingService.call(message, :create_service, instantiation_request[:id])
    rescue => e
      ArgumentError.new(e.message)
    end
    instantiation_request
  end
  
  def self.build_message(service, functions, egresses, ingresses, user_data)
    msg=self.name+'.'+__method__.to_s
    #STDERR.puts "#{msg}: service=#{service}\n\tfunctions=#{functions}"
    message = {}
    nsd = service[:nsd]
    nsd[:uuid] = service[:uuid]
    message['NSD']=nsd
    nsd[:network_functions].each_with_index do |vnf, index|
      vnfd = functions[index][:vnfd]
      vnfd[:uuid] = functions[index][:uuid]
      message["VNFD#{index}"]=vnfd 
    end
    STDERR.puts "#{msg}: message=#{message}"
    message['egresses'] = egresses
    message['ingresses'] = ingresses
    message['user_data'] = user_data
    deep_stringify_keys(message).to_yaml
  end
  
  def self.transform_hash(original, options={}, &block)
    original.inject({}){|result, (key,value)|
      value = if (options[:deep] && Hash === value) 
                transform_hash(value, options, &block)
              else 
                if Array === value
                  value.map{|v| transform_hash(v, options, &block)}
                else
                  value
                end
              end
      block.call(result,key,value)
      result
    }
  end

  # Convert keys to strings
  def self.stringify_keys(hash)
    transform_hash(hash) {|hash, key, value|
      hash[key.to_s] = value
    }
  end

  # Convert keys to strings, recursively
  def self.deep_stringify_keys(hash)
    transform_hash(hash, :deep => true) {|hash, key, value|
      hash[key.to_s] = value
    }
  end

  def augment_params(body)
    params = JSON.parse(body, quirks_mode: true, symbolize_names: true)
    @egresses = []
    @ingresses = []
    
    @egresses = params.delete[:egresses] if params[:egresses]
    @ingresses = params.delete[:ingresses] if params[:ingresses]
    @user_data = FetchUserDataService.call(request.env['5gtango.user.data'])
    params
  end
end
