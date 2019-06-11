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
require 'active_support'
require_relative './fetch_nsd_service'
require_relative './fetch_vnfds_service'
require_relative './fetch_service_records_service'
require_relative './fetch_flavour_from_sla_service'
require_relative './fetch_license_service'
require_relative './fetch_slas_for_service'
require_relative './message_publishing_service'
require_relative '../models/request'
require_relative './process_request_base'
require 'tng/gtk/utils/logger'

class ProcessRequestService < ProcessRequestBase
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name

  def self.call(params)
    msg='.'+__method__.to_s
    request_type = params.fetch(:request_type, 'CREATE_SERVICE')
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"params=#{params}")
    
    begin
      # ToDo:
      # This is temporary, the 'else' branch will disappear when we have this tested for the Slice creation only
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"request_type=#{request_type}")
      return send(request_type.downcase.to_sym, params)
    rescue NoMethodError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"'#{request_type}' is not valid as a request type\n#{e.message}\n#{e.backtrace.join("\n\t")}")
      raise ArgumentError.new("'#{request_type}' is not valid as a request type\n#{e.message}\n#{e.backtrace.join("\n\t")}")
    end
  end

  def self.enrich_one(request)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"request=#{request.inspect} (class #{request.class})")
    case request[:request_type]
    when 'CREATE_SERVICE'
      service_uuid = request.delete :service_uuid
      if (!service_uuid || service_uuid.empty?)
        LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"service_uuid is blank")
        return recursive_symbolize_keys(request) 
      end
    when 'TERMINATE_SERVICE'
      request.delete :service_uuid if request.key? :service_uuid
      if (!request[:instance_uuid] || request[:instance_uuid].empty?)
        LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Network Service instance UUID is empty")
        return recursive_symbolize_keys(request) 
      end
      service_record = FetchServiceRecordsService.call(uuid: request[:instance_uuid])
      if (!service_record || service_record.empty?)
        LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Problem fetching service record for instance UUID '#{request[:instance_uuid]}")
        return recursive_symbolize_keys(request) 
      end
      if (!service_record[:descriptor_reference] || service_record[:descriptor_reference].empty?)
        LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Network Service UUID is empty in service record #{service_record}")
        return recursive_symbolize_keys(request) 
      end
      service_uuid = service_record[:descriptor_reference]
    else
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"request type '#{request[:request_type]}'")
      return recursive_symbolize_keys(request) 
    end
    service = FetchNSDService.call(uuid: service_uuid)
    if (!service || service.empty?)
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Network Service Descriptor '#{service_uuid}' wasn't found")
      return recursive_symbolize_keys(request) 
    end
    enriched = request
    enriched[:service] = {}
    enriched[:service][:uuid] = service_uuid
    enriched[:service][:vendor] = service[:nsd][:vendor]
    enriched[:service][:name] = service[:nsd][:name]
    enriched[:service][:version] = service[:nsd][:version]
    slas = FetchSLAsForService.call(uuid: service_uuid)
    if (!slas || slas.empty?)
      LOGGER.info(component:LOGGED_COMPONENT, operation: msg, message:"Network Service Descriptor '#{service_uuid}' does not have an SLA")
      return recursive_symbolize_keys(request) 
    end
    enriched[:slas] = slas
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"enriched='#{enriched}'")
    recursive_symbolize_keys(enriched)
  end
  
  def self.enrich(requests)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"requests=#{requests.inspect} (class #{requests.class})")
    unless requests.is_a?(Array)
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"requests needs to be an array")
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
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"params=#{params}")
    begin
      valid = valid_create_service_params?(params)
      if (valid && valid.key?(:error) )
        LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"validation failled with error #{valid[:error]}")
        return valid
      end
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"params[:sla_id]=#{params[:sla_id]} (class #{params[:sla_id].class})")
      
      unless invalid_sla_id?(params[:sla_id])
        #{ "current_instances": "0", "allowed_instances": "20", "allowed_to_instantiate": "false",
        #  "license_type": "private", "license_status": "test", "license_expiration_date": "2020-12-01T00:00:00Z"}
        license = FetchLicenseService.call(params[:service_uuid], params[:sla_id])
        if (license == nil || license == '')
          error = "License not found for service '#{params[:service_uuid]}' and SLA '#{params[:sla_id]}'"
          LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:error)
          return {error: error}
        end
        unless license[:allowed_to_instantiate]
          case license[:license_type]
          when 'private'
            bought_license = FetchLicenseService.buy(params[:service_uuid], params[:sla_id])
            if (bought_license == nil || bought_license == '')
              error = "Could not buy license for service '#{params[:service_uuid]}' and SLA '#{params[:sla_id]}'"
              LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:error)
              return {error: error}
            end
          when 'public', 'trial'
            LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Instantiation not allowed for service '#{params[:service_uuid]}' and SLA '#{params[:sla_id]}'. NS instances reached the maximum allowed number")
            return {error: "Instantiation not allowed for service '#{params[:service_uuid]}' and SLA '#{params[:sla_id]}'. NS instances reached the maximum allowed number"}
          else
            LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"License type '#{license[:license_type]}' no supported")
            return {error: "License type '#{license[:license_type]}' no supported"}
          end
        end
        params[:flavor] = FetchFlavourFromSLAService.call(params[:service_uuid], params[:sla_id])  
      end
      
      # blacklist, ingresses, egresses and mapping are stored in JSON
      params[:blacklist] = params[:blacklist].to_json if params.key?(:blacklist)
      params[:ingresses] = params[:ingresses].to_json if params.key?(:ingresses)
      params[:egresses] = params[:egresses].to_json if params.key?(:egresses)
      params[:mapping] = params[:mapping].to_json if params.key?(:mapping)
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"params=#{params}")
      instantiation_request = nil
      begin
        #LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:">>> Before Request.create: #{Request.connection_pool.stat}")
        instantiation_request = Request.create(params).as_json
        #LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:">>> After Request.create: #{Request.connection_pool.stat}")
      ensure
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:">>> No connections for Request.create: #{Request.connection_pool.stat}")
        Request.connection_pool.flush!
        Request.clear_active_connections!
      end
      unless instantiation_request
        LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Failled to create instantiation_request for service '#{params[:service_uuid]}'")
        return {error: "Failled to create instantiation request for service '#{params[:service_uuid]}'"}
      end
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"instantiation_request=#{instantiation_request} ")

      # fetch stuff to build message
      stored_service = FetchNSDService.call(uuid: params[:service_uuid])
      return stored_service if (!stored_service || stored_service.empty?)
      stored_functions = fetch_functions(stored_service[:nsd][:network_functions])
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"stored_functions=#{stored_functions}")
      return nil if stored_functions == nil 
      user_data = complete_user_data(params[:customer_name], params[:customer_email], stored_service.fetch(:username, ''), params[:sla_id])
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"user_data=#{user_data}")

      message = build_message(stored_service, stored_functions, params[:egresses], params[:ingresses], params[:blacklist], user_data, params[:flavor], params[:mapping])
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"instantiation_request[:id]=#{instantiation_request[:id]}")
      published_response = MessagePublishingService.call(message, :create_service, instantiation_request[:id])
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"published_response=#{published_response}")
    rescue StandardError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"(#{e.class}) #{e.message}\n#{e.backtrace.split('\n\t')}")
      return nil
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"instantiation_request=#{instantiation_request}")
    instantiation_request
  end

  def self.terminate_service(params)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"params=#{params}")
    begin
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"before validation...")
      valid = valid_terminate_service_params?(params)
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"valid is #{valid}")
      if (valid && !valid.empty? && valid.key?(:error) )
        LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"validation failled with error '#{valid[:error]}'")
        return valid
      end
      params[:name] = valid[:name]
      begin
        termination_request = Request.create(params).as_json
      ensure
        Request.connection_pool.flush!
        Request.clear_active_connections!
      end
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"termination_request=#{termination_request}")
      unless termination_request
        LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Failled to create termination_request")
        return {error: "Failled to create termination request for service instance '#{params[:instance_uuid]}'"}
      end
      published_response = MessagePublishingService.call({'service_instance_uuid'=> params[:instance_uuid]}.to_yaml.to_s, :terminate_service, termination_request[:id])
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"published_response=#{published_response.inspect}")
    rescue StandardError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"#{e.message} (#{e.class}): #{e.backtrace.split('\n\t')}")
      return nil
    end
    termination_request
  end
  
  def self.build_message(service, functions, egresses, ingresses, blacklist, user_data, flavor, mapping)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"service=#{service}\nfunctions=#{functions}")
    message = {}
    nsd = service[:nsd]
    nsd[:uuid] = service[:uuid]
    message['NSD']=nsd
    functions.each_with_index do |vnf, index|
      vnfd = functions[index][:vnfd]
      vnfd[:uuid] = functions[index][:uuid]
      message["VNFD#{index}"]=vnfd 
    end
    message['user_data'] = user_data
    message['flavor'] = flavor
    begin
      message['blacklist'] = JSON.parse(blacklist) if blacklist
      message['egresses'] = JSON.parse(egresses) if egresses
      message['ingresses'] = JSON.parse(ingresses) if ingresses
      message['mapping'] = JSON.parse(mapping) if mapping
    rescue JSON::ParserError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error parsing blacklist ('#{blacklist}'), egresses ('#{egresses}'), ingresses ('#{ingresses}'), or mapping ('#{mapping}')")
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"message=#{message}")
    recursive_stringify_keys(message).to_yaml.to_s
  end
  
  def self.valid_create_service_params?(params)
    msg='.'+__method__.to_s
    if params[:service_uuid].to_s.empty?
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"Creation of a service needs the service UUID")
      return {error: "Creation of a service needs the service UUID"} 
    end
    {}
  end
  
  def self.valid_terminate_service_params?(params)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"params=#{params}")
    unless (params.fetch(:instance_uuid) && params[:instance_uuid] != '')
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Termination of a service instance needs the instance UUID")
      return {error: "Termination of a service instance needs the instance UUID"} 
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"params[:instance_uuid] is there...")
    unless valid_uuid?(params[:instance_uuid])
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Instance UUID '#{params[:instance_uuid]}' is not valid")
      return {error: "Instance UUID '#{params[:instance_uuid]}' is not valid"} 
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"params[:instance_uuid] has a valid UUID...")
    begin
      request = Request.where(instance_uuid: params[:instance_uuid], request_type: 'CREATE_SERVICE').as_json
    ensure
      Request.connection_pool.flush!
      Request.clear_active_connections!
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"request=#{request}")
    if request.is_a?(Array)
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"request is an array, chosen #{request[0]}")
      request = request[0] 
    end
    if (!request || request.empty?)
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Service instantiation request for service instance UUID '#{params[:instance_uuid]}' not found")
      return {error: "Service instantiation request for service instance UUID '#{params[:instance_uuid]}' not found"} 
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"found creation request for instance uuid '#{params[:instance_uuid]}': #{request}")
    #return {error: "Service instantiation request for service instance UUID '#{params[:instance_uuid]}' is #{request['status']}' (and not 'READY')"} unless request['status'] == 'READY'
    #record = FetchServiceRecordsService(uuid: params[:instance_uuid])
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
    
  def self.invalid_sla_id?(uuid)
    uuid.nil? || uuid.empty?
  end
  
  def self.complete_user_data(customer_name, customer_email, developer_name, sla_id)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"customer_name=#{customer_name}, developer_name=#{developer_name}, sla_id=#{sla_id}")
    {
      customer: { name: customer_name, email: customer_email, sla_id: sla_id}, 
      developer: { username: developer_name, email: '', phone: ''}
    }
  end

  def self.fetch_functions(list_of_functions)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"list_of_functions=#{list_of_functions}")
    list = []
    list_of_functions.each do |function|
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"function=#{function}")
      found_function = FetchVNFDsService.call({vendor: function[:vnf_vendor], name: function[:vnf_name], version: function[:vnf_version]})
      LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"found_function=#{found_function}")
      if (!found_function || found_function.empty?)
        LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Function #{function} not found")
        return nil
      end
      list << found_function.first
    end
    list
  end
end