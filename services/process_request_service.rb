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
      # ToDo:
      # This is temporary, the 'else' branch will disappear when we have this tested for the Slice creation only
      STDERR.puts "#{msg}: request_type=#{request_type}"
      if request_type == 'CREATE_SLICE'
        klass_name = "Process#{ActiveSupport::Inflector.camelize(request_type.downcase)}InstanceRequest" #ProcessCreateSliceInstanceRequest
        klass = ActiveSupport::Inflector.constantize(klass_name)
        STDERR.puts "#{msg}: CREATE_SLICE: class #{klass.name}"
        return klass.call(params)
      else
        return send(request_type.downcase.to_sym, params)
      end
    rescue NoMethodError => e
      raise ArgumentError.new("'#{request_type}' is not valid as a request type\n#{e.message}\n#{e.backtrace.join("\n\t")}")
    end
  end

  def self.enrich_one(request)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: request=#{request.inspect} (class #{request.class})"
    case request['request_type']
    when 'CREATE_SERVICE'
      service_uuid = request.delete 'service_uuid'
      if (!service_uuid || service_uuid.empty?)
        STDERR.puts "#{msg}: service_uuid is blank"
        return recursive_symbolize_keys(request) 
      end
    when 'TERMINATE_SERVICE'
      request.delete 'service_uuid' if request.key? 'service_uuid'
      if (!request['instance_uuid'] || request['instance_uuid'].empty?)
        STDERR.puts "#{msg}: Network Service instance UUID is empty"
        return recursive_symbolize_keys(request) 
      end
      service_record = FetchServiceRecordsService.call(uuid: request['instance_uuid'])
      if (!service_record || service_record.empty?)
        STDERR.puts "#{msg}: Problem fetching service record for instance UUID '#{request['instance_uuid']}"
        return recursive_symbolize_keys(request) 
      end
      if (!service_record[:descriptor_reference] || service_record[:descriptor_reference].empty?)
        STDERR.puts "#{msg}: Network Service UUID is empty in service record #{service_record}"
        return recursive_symbolize_keys(request) 
      end
      service_uuid = service_record[:descriptor_reference]
    else
      STDERR.puts "#{msg}: request type '#{request['request_type']}'"
      return recursive_symbolize_keys(request) 
    end
    service = FetchNSDService.call(uuid: service_uuid)
    if (!service || service.empty?)
      STDERR.puts "#{msg}: Network Service Descriptor '#{service_uuid}' wasn't found"
      return recursive_symbolize_keys(request) 
    end
    enriched = request
    enriched[:service] = {}
    enriched[:service][:uuid] = service_uuid
    enriched[:service][:vendor] = service[:nsd][:vendor]
    enriched[:service][:name] = service[:nsd][:name]
    enriched[:service][:version] = service[:nsd][:version]
    STDERR.puts "#{msg}: enriched='#{enriched}'"
    recursive_symbolize_keys(enriched)
  end
  
  def self.enrich(requests)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: requests=#{requests.inspect} (class #{requests.class})"
    unless requests.is_a?(Array)
      STDERR.puts "#{msg}: requests needs to be an array"
      return requests
    end
    enriched = []
    requests.each do |request|
      enriched << enrich_one(request.as_json)
    end
    enriched
  end
    
  private
  
  def self.create_service(params)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: params=#{params}"
    begin
      valid = valid_create_service_params?(params)
      if (valid && valid.key?(:error) )
        STDERR.puts "#{msg}: validation failled with error #{valid[:error]}"
        return valid
      end
      
      completed_params = complete_params(params)
      STDERR.puts "#{msg}: completed params=#{completed_params}"
      stored_service = FetchNSDService.call(uuid: completed_params[:service_uuid])
      STDERR.puts "#{msg}: stored_service=#{stored_service} (#{stored_service.class})"
      return stored_service if (!stored_service || stored_service.empty?)
      functions_to_fetch = stored_service[:nsd][:network_functions]
      STDERR.puts "#{msg}: functions_to_fetch=#{functions_to_fetch}"
      stored_functions = fetch_functions(functions_to_fetch)
      STDERR.puts "#{msg}: stored_functions=#{stored_functions}"
      return nil if stored_functions == nil 
      instantiation_request = Request.create(completed_params).as_json
      STDERR.puts "#{msg}: instantiation_request=#{instantiation_request} (class #{instantiation_request.class})"
      unless instantiation_request
        STDERR.puts "#{msg}: Failled to create instantiation_request"
        return {error: "Failled to create instantiation request for service '#{params[:service_uuid]}'"}
      end
      complete_user_data = FetchUserDataService.call( completed_params[:customer_uuid], stored_service[:username], completed_params[:sla_id])
      STDERR.puts "#{msg}: complete_user_data=#{complete_user_data}"
      message = build_message(stored_service, stored_functions, completed_params[:egresses], completed_params[:ingresses], completed_params[:blacklist], complete_user_data)
      STDERR.puts "#{msg}: instantiation_request['id']=#{instantiation_request['id']}"
      published_response = MessagePublishingService.call(message, :create_service, instantiation_request['id'])
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
      if (valid && !valid.empty? && valid.key?(:error) )
        STDERR.puts "#{msg}: validation failled with error '#{valid[:error]}'"
        return valid
      end
      params[:name] = valid[:name]
      termination_request = Request.create(params).as_json
      STDERR.puts "#{msg}: termination_request=#{termination_request}"
      unless termination_request
        STDERR.puts "#{msg}: Failled to create termination_request"
        return {error: "Failled to create termination request for service instance '#{params[:instance_uuid]}'"}
      end
      published_response = MessagePublishingService.call({'service_instance_uuid'=> params[:instance_uuid]}.to_yaml.to_s, :terminate_service, termination_request['id'])
      STDERR.puts "#{msg}: published_response=#{published_response.inspect}"
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
    return {error: "Creation of a service needs the service UUID"} if params[:service_uuid].empty?
    {}
  end
  
  def self.valid_terminate_service_params?(params)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: params=#{params}"
    return {error: "Termination of a service instance needs the instance UUID"} if (params[:instance_uuid] && params[:instance_uuid].empty?)
    STDERR.puts "#{msg}: params[:instance_uuid] is there..."
    return {error: "Instance UUID '#{params[:instance_uuid]}' is not valid"} unless valid_uuid?(params[:instance_uuid])
    STDERR.puts "#{msg}: params[:instance_uuid] has a valid UUID..."
    STDERR.puts "#{msg}: before Request.where: #{ActiveRecord::Base.connection_pool.stat}"
    request = Request.where(instance_uuid: params[:instance_uuid], request_type: 'CREATE_SERVICE').as_json
    STDERR.puts "#{msg}: after Request.where: #{ActiveRecord::Base.connection_pool.stat}"
    STDERR.puts "#{msg}: request=#{request}"
    if request.is_a?(Array)
      STDERR.puts "#{msg}: request is an array, chosen #{request[0]}"
      request = request[0] 
    end
    return {error: "Service instantiation request for service instance UUID '#{params[:instance_uuid]}' not found"} if (!request || request.empty?)
    STDERR.puts "#{msg}: found creation request for instance uuid '#{params[:instance_uuid]}': #{request}"
    #STDERR.puts "#{msg}: request['status']='#{request['status']}'"
    #return {error: "Service instantiation request for service instance UUID '#{params[:instance_uuid]}' is #{request['status']}' (and not 'READY')"} unless request['status'] == 'READY'
    #record = FetchServiceRecordsService(uuid: params[:instance_uuid])
    #STDERR.puts "#{msg}: record=#{record.inspect} (class #{record.class})"
    #return {error: "Service instance UUID '#{params[:instance_uuid]}' not found"} if (record.empty? || record.nil?)
    {name: request['name']}
  end
  
  # https://stackoverflow.com/questions/8379596/how-do-i-convert-a-ruby-hash-so-that-all-of-its-keys-are-symbols
  def self.recursive_symbolize_keys(h)
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
      if (!found_function || found_function.empty?)
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