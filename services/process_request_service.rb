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
  ERROR_VNF_CATALOGUE_URL_NOT_FOUND='VNF Catalogue URL not found in the ENV.'

  def self.call(params)
    msg=self.name+'.'+__method__.to_s
    request_type = params.fetch(:request_type, 'CREATE_SERVICE')
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
      unless (valid = valid_create_service_params?(params)) == {}
        STDERR.puts "#{msg}: validation failled with error #{valid[:error]}"
        return valid
      end
      
      complete_params = complete_params(params)
      STDERR.puts "#{msg}: completed params=#{complete_params}"
      stored_service = FetchNSDService.call(uuid: complete_params[:service_uuid])
      STDERR.puts "#{msg}: stored_service=#{stored_service} (#{stored_service.class})"
      return stored_service if (stored_service == {} || stored_service == nil)
      functions_to_fetch = stored_service[:nsd][:network_functions]
      STDERR.puts "#{msg}: functions_to_fetch=#{functions_to_fetch}"
      stored_functions = fetch_functions(functions_to_fetch)
      STDERR.puts "#{msg}: stored_functions=#{stored_functions}"
      return stored_functions if stored_functions == nil 
      instantiation_request = Request.create(complete_params)
      unless instantiation_request
        STDERR.puts "#{msg}: Failled to create instantiation_request"
        return {error: "Failled to create instantiation request for service '#{params[:service_uuid]}'"}
      end
      STDERR.puts "#{msg}: instantiation_request=#{instantiation_request.inspect}"
      complete_user_data = FetchUserDataService.call( complete_params[:customer_uuid], stored_service[:username], complete_params[:sla_id])
      STDERR.puts "#{msg}: complete_user_data=#{complete_user_data}"
      message = build_message(stored_service, stored_functions, complete_params[:egresses], complete_params[:ingresses], complete_params[:blacklist], complete_user_data)
      STDERR.puts "#{msg}: instantiation_request[:id]=#{instantiation_request[:id]}"
      published_response = MessagePublishingService.call(message, :create_service, instantiation_request[:id])
      STDERR.puts "#{msg}: published_response=#{published_response}"
    #rescue ActiveRecord::StatementInvalid => e
    #  STDERR.puts "#{msg}: #{e.message}\n#{e.backtrace.spli('\n\t')}"
    #  return {}
    #rescue ActiveRecord::ConnectionTimeoutError => e
    #  STDERR.puts "#{msg}: #{e.message}\n#{e.backtrace.spli('\n\t')}"
    #  return {}
    rescue StandardError => e
      STDERR.puts "#{msg}: (#{e.class}) #{e.message}\n#{e.backtrace.spli('\n\t')}"
      return nil
    end
    instantiation_request
  end

  def self.terminate_service(params)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: params=#{params}"
    begin
      STDERR.puts "#{msg}: before validation..."
      valid = valid_terminate_service_params?(params)
      STDERR.puts "#{msg}: valid is #{valid}"
      unless valid == {}
        STDERR.puts "#{msg}: validation failled with error '#{valid[:error]}'"
        return valid
      end
      termination_request = Request.create(params)
      unless termination_request
        STDERR.puts "#{msg}: Failled to create termination_request"
        return {error: "Failled to create termination request for service instance '#{params[:instance_uuid]}'"}
      end
      STDERR.puts "#{msg}: termination_request=#{termination_request.inspect}"
      published_response = MessagePublishingService.call(params.to_yaml.to_s, :terminate_service, termination_request[:id])
      STDERR.puts "#{msg}: published_response=#{published_response}"
    rescue StandardError => e
      STDERR.puts "#{msg}: (#{e.class}) #{e.message}\n#{e.backtrace.spli('\n\t')}"
      return nil
    end
    termination_request
  end
  
  def self.build_message(service, functions, egresses, ingresses, blacklist, user_data)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: service=#{service}"
    STDERR.puts "#{msg}: functions=#{functions}"
    message = {}
    nsd = service[:nsd]
    nsd[:uuid] = service[:uuid]
    message['NSD']=nsd
    #STDERR.puts "#{msg}: message['NSD']=#{message['NSD']}"
    functions.each_with_index do |vnf, index|
      vnfd = functions[index][:vnfd]
      #STDERR.puts "#{msg}: vnfd=#{vnfd}"
      vnfd[:uuid] = functions[index][:uuid]
      message["VNFD#{index}"]=vnfd 
      #STDERR.puts "#{msg}: message['VNFD#{index}']=#{message["VNFD#{index}"]}"
    end
    message['egresses'] = egresses
    message['ingresses'] = ingresses
    message['blacklist'] = blacklist
    message['user_data'] = user_data
    STDERR.puts "#{msg}: message=#{message}"
    #STDERR.puts "#{msg}: deep_stringify_keys(message).to_yaml=#{deep_stringify_keys(message).to_yaml}"
    recursive_stringify_keys(message).to_yaml.to_s
  end
  
  def self.valid_create_service_params?(params)
    return {error: "Creation of a service needs the service UUID"} if params[:service_uuid] == ''
    {}
  end
  
  def self.valid_terminate_service_params?(params)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: params=#{params}"
    return {error: "Termination of a service instance needs the instance UUID"} if (params[:instance_uuid] && params[:instance_uuid] == '')
    STDERR.puts "#{msg}: params[:instance_uuid] is there..."
    return {error: "Instance UUID '#{params[:instance_uuid]}' is not valid"} unless valid_uuid?(params[:instance_uuid])
    STDERR.puts "#{msg}: params[:instance_uuid] has a valid UUID..."
    request = Request.where('instance_uuid = ?',params[:instance_uuid])
    STDERR.puts "#{msg}: request=#{request.inspect}"
    return {error: "Service instantiation request for service instance UUID '#{params[:instance_uuid]}' not found"} if request.empty?
    STDERR.puts "#{msg}: found params[:instance_uuid]"
    return {error: "Service instantiation request for service instance UUID '#{params[:instance_uuid]}' is not 'READY'"} unless request.status == 'READY'
    record = FetchServiceRecordsService(uuid: params[:instance_uuid])
    STDERR.puts "#{msg}: record=#{record.inspect} (class #{record.class})"
    return {error: "Service instance UUID '#{params[:instance_uuid]}' not found"} if (record == {} || record == nil)
    {}
  end
  
  # https://stackoverflow.com/questions/8379596/how-do-i-convert-a-ruby-hash-so-that-all-of-its-keys-are-symbols
  def recursive_symbolize_keys(h)
    case h
    when Hash
      Hash[
        h.map do |k, v|
          [ k.respond_to?(:to_sym) ? k.to_sym : k, recursive_symbolize_keys(v) ]
        end
      ]
    when Enumerable
      h.map { |v| recursive_symbolize_keys(v) }
    else
      h
    end
  end
  
  # adpated from the above
  def self.recursive_stringify_keys(h)
    case h
    when Hash
      Hash[
        h.map do |k, v|
          [ k.respond_to?(:to_s) ? k.to_s : k, recursive_stringify_keys(v) ]
        end
      ]
    when Enumerable
      h.map { |v| recursive_stringify_keys(v) }
    else
      h
    end
  end
  
  def self.complete_params(params)
    complement = {}
    [:egresses, :ingresses, :blacklist].each do |element|
      complement[element] = [] unless params.key?(element)
    end
    complement[:request_type] = 'CREATE_SERVICE' unless params.key?(:request_type)
    complement[:customer_uuid] = params.fetch(:customer_uuid, '')
    complement[:sla_id] = params.fetch(:sla_id, '')
    complement[:callback] = params.fetch(:callback, '')
    params.merge(complement)
  end
  
  def self.fetch_functions(list_of_functions)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: list_of_functions=#{list_of_functions}"
    list = []
    list_of_functions.each do |function|
      STDERR.puts "#{msg}: function=#{function}"
      found_function = FetchVNFDsService.call({vendor: function[:vnf_vendor], name: function[:vnf_name], version: function[:vnf_version]})
      STDERR.puts "#{msg}: found_function=#{found_function}"
      if found_function == [] or found_function == nil
        STDERR.puts "#{msg}: Function #{function} not found"
        return nil
      end
      list << found_function.first
    end
    list
  end
  
  def self.valid_uuid?(uuid)
    uuid.match /[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}/
    uuid == $&
  end
end