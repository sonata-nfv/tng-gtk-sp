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
require 'securerandom'
require 'net/http'
require 'uri'
require 'ostruct'
require 'json'
require 'yaml'
require_relative './process_request_base'
require_relative '../models/request'
require 'tng/gtk/utils/logger'

class ProcessMigrateFunctionInstanceRequest < ProcessRequestBase
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  
  def self.call(params)
    new.call(params)
  end
  
  def call(params)
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"params=#{params}")
    valid = valid_request?(params)
    
    if (valid && valid.key?(:error) )
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"validation failled with error #{valid[:error]}")
      return valid
    end
    
    completed_params = complete_params(params)
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"completed params=#{completed_params}")
    begin
      scaling_request = Request.create(completed_params).as_json
    ensure
      Request.clear_active_connections!
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"scaling_request=#{scaling_request} (class #{scaling_request.class})")
    unless scaling_request
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"Failled to create scaling request for service instance '#{params[:instance_uuid]}'")
      return {error: "Failled to create the scale request #{params}"}
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"scaling_request=#{scaling_request}")
    message = build_message(completed_params[:scaling_type], completed_params[:instance_uuid], completed_params[:vnfd_uuid], completed_params[:number_of_instances], completed_params[:vim_uuid])
    begin
     published_response = MessagePublishingService.call(message, :migrate_function, scaling_request[:id])
     LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"published_response=#{published_response}")
    rescue StandardError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation: msg, message:"(#{e.class}) #{e.message}\n#{e.backtrace.split('\n\t')}")
      return {error: "#{LOGGED_COMPONENT}#{msg} (#{__LINE__}):\n#{e.message}\n#{e.backtrace.split('\n\t')}"}
    end
    scaling_request
  end
  
  def self.enrich_one(request)
    new.enrich_one(request)
  end
  def enrich_one(request)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"request=#{request.inspect} (class #{request.class})")
    request
  end
  
  private
  def valid_request?(params)
=begin
topic: service.instance.migrate
payload:

---
service_instance_uuid: <id of the service instance>
vnf_uuid: <id of the vnf instance that needs to be migrated>
vim_uuid: <id of the vim that the vnf needs to be migrated to>
=end
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"params=#{params}")

    return {error: "The type of scaling must be present"} unless params.key?(:scaling_type)
    return {error: "The type of scaling must be either ADD_VNF or REMOVE_VNF"} unless (params[:scaling_type].upcase == "ADD_VNF" || params[:scaling_type].upcase == "REMOVE_VNF")
    return {error: "The service instance UUID must be present"} unless params.key?(:instance_uuid)
    return {error: "The service instance UUID must be valid"} unless uuid_valid?(params[:instance_uuid])
    return {error: "Either the VNFD UUID or the VNF UUID must be present on a scale in (REMOVE_VNF)"} if (params[:scaling_type].upcase == "REMOVE_VNF" && !params.key?(:vnfd_uuid) && !params.key?(:vnf_uuid))
    return {error: "The VNFD UUID must be present"} if (params[:scaling_type].upcase == "ADD_VNF" && !params.key?(:vnfd_uuid))
    return {error: "The VNFD UUID must be valid"} if (params.key?(:vnfd_uuid) && !uuid_valid?(params[:vnfd_uuid]))
    return {error: "The VNF UUID must be valid"} if (params.key?(:vnf_uuid) && !uuid_valid?(params[:vnf_uuid]))
    return {error: "The number of instances must be greater than 0 (defaults to one, if absent)"} if (params.key?(:number_of_instances) && params[:number_of_instances].to_i < 1)
    return {error: "The VIM UUID must be valid"} if (params[:scaling_type].upcase == "ADD_VNF" && params.key?(:vim_uuid) && !uuid_valid?(params[:vim_uuid]))
    {}
  end
  
  def complete_params(params)
    new_params = params.dup
    new_params[:vim_uuid] = params.fetch(:vim_uuid, '')
    new_params[:number_of_instances] = params.fetch(:number_of_instances, 1)
    new_params
  end
  
  def build_message(scaling_type, instance_uuid, vnfd_uuid, number_of_instances, vim_uuid)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"scaling_type=#{scaling_type} instance_uuid=#{instance_uuid} vnfd_uuid=#{vnfd_uuid}")
    message = {}
    message['scaling_type'] = scaling_type
    message['service_instance_uuid'] = instance_uuid
    message['vnfd_uuid'] = vnfd_uuid
    message['number_of_instances'] = number_of_instances.to_i
    if vim_uuid
      message['constraints'] = {'vim_uuid'=>vim_uuid}
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation: msg, message:"message=#{message}")
    message.to_yaml.to_s
  end  
  
  def enrich_params(params)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"params=#{params}")
    params
  end
  
  def uuid_valid?(uuid)
    return true if (uuid =~ /[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}/) == 0
    false
  end
end
