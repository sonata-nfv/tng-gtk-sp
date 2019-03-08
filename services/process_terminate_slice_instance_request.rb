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

class ProcessTerminateSliceInstanceRequest < ProcessRequestBase
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  
  NO_SLM_URL_DEFINED_ERROR='The SLM_URL ENV variable needs to be defined and pointing to the Slice Manager component, where to request the termination of a Network Slice'
  SLM_URL = ENV.fetch('SLM_URL', '')
  if SLM_URL == ''
    LOGGER.error(component:LOGGED_COMPONENT, operation:'fetching SLM_URL ENV variable', message:NO_SLM_URL_DEFINED_ERROR)
    raise ArgumentError.new(NO_SLM_URL_DEFINED_ERROR) 
  end
  SLICE_INSTANCE_CHANGE_CALLBACK_URL = ENV.fetch('SLICE_INSTANCE_CHANGE_CALLBACK_URL', 'http://tng-gtk-sp:5000/requests')
  
  def self.call(params)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"params=#{params}")
    begin
      valid = valid_request?(params)
      if (valid && valid.is_a?(Hash) && valid.key?(:error) )
        LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"validation failled with error #{valid[:error]}")
        return valid
      end
      
      enriched_params = enrich_params(params)
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"enriched_params params=#{enriched_params}")
      
      termination_request = Request.create(enriched_params)
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"termination_request=#{termination_request.inspect} (class #{termination_request.class})")
      unless termination_request
        LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Failled to create termination request")
        return {error: "Failled to create termination request for slice instance '#{params[:instance_uuid]}'"}
      end
      # pass it to the Slice Manager
      # {"instance_uuid":"3a2535d6-8852-480b-a4b5-e216ad7ba55f", "tarminate_at":"..."}
      # the user callback is saved in the request
      enriched_params[:callback] = "#{SLICE_INSTANCE_CHANGE_CALLBACK_URL}/#{termination_request['id']}/on-change"
      request = request_slice_termination(enriched_params)
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"request=#{request}")
      if (request && request.is_a?(Hash) && request.key?(:error))
        termination_request.update(status: 'ERROR', error: request[:error])
      end
      return termination_request.as_json
    rescue StandardError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"(#{e.class}) #{e.message}\n#{e.backtrace.split('\n\t')}")
      return {error: "#{e.message}"}
    end
  end
  
  # "/api/nsilcm/v1/nsi/on-change"
  # @app.route(API_ROOT+API_NSILCM+API_VERSION+API_NSI+'/update_NSIservinstance', methods=['POST'])
  # GET http://tng-slice-mngr:5998/api/nst/v1/descriptors
  def self.process_callback(event)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"event=#{event}")
    result = save_result(event)
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result=#{result}")
    notify_user(result) unless result[:callback].to_s.empty?
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"after notify user (#{result[:callback]})")
    result
  end
  
  def self.enrich_one(request)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"request=#{request.inspect} (class #{request.class})")
    request
  end
  
  private  
  def self.save_result(event)
    msg='.'+__method__.to_s
    original_request = Request.find(event[:original_event_uuid]) #.as_json
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"original request = #{original_request.inspect}")
    original_request['status'] = event[:nsiState]
    original_request['error'] = event[:error] # Pol to add it
    original_request.save
    original_request.as_json
  end
  
  def self.notify_user(result)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"entered, result=#{result}")
    
    uri = URI.parse(result[:callback])

    # Create the HTTP objects
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request.body = result.to_json
    request['Content-Type']='application/json'
    
    # Send the request
    begin
      response = http.request(request)
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"response=#{response}")
      case response
      when Net::HTTPSuccess, Net::HTTPCreated
        body = response.body
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"#{response.code} body=#{body}")
        return JSON.parse(body, quirks_mode: true, symbolize_names: true)
      else
        LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"#{response.message}")
        return {error: "#{response.message}"}
      end
    rescue Exception => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Failled to post to user's callback #{result[:callback]} with message #{e.message}")
    end
    nil
  end

  def self.valid_request?(params)
    msg='.'+__method__.to_s
    # { "request_type":"TERMINATE_SLICE", "instance_uuid":"3a2535d6-8852-480b-a4b5-e216ad7ba55f", "terminate_at":0, "callback":"http://..."}
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"params=#{params}")
    true
  end
  
  def self.enrich_params(params)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"params=#{params}")
    params
  end
  
  def self.request_slice_termination(params)
    msg='.'+__method__.to_s
    # POST http://tng-slice-mngr:5998/api/nsilcm/v1/nsi/<nsiId>/terminate, with body {'callback':'http://...'}
    # curl -i -H "Content-Type:application/json" -X POST -d '{"terminateTime": "_time_", "callback":"URL_with_callback_request"}' http://{base_url}:5998/api/nsilcm/v1/nsi/<nsiId>/terminate
    site = "#{SLM_URL}/nsilcm/v1/nsi/#{params[:instance_uuid]}/terminate"
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"params=#{params} site=#{site}")
    uri = URI.parse(site)

    # Create the HTTP objects
    http = Net::HTTP.new(uri.host, uri.port)
    #http.read_timeout = 500 # seconds
    request = Net::HTTP::Post.new(uri)
    request_params = {}
    request_params[:terminateTime] = params.key?(:terminate_at) ? params[:terminate_at] : 0
    request_params[:callback] = params.key?(:callback) ? params[:callback] : ''
    request.body = request_params.to_json
    request['Content-Type'] ='application/json'
    
    # Send the request
    begin
      response = http.request(request)
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"response=#{response}")
      case response
      when Net::HTTPSuccess, Net::HTTPCreated
        body = response.body
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"body=#{body}")
        return JSON.parse(body, quirks_mode: true, symbolize_names: true)
      else
        LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"#{response.code} (#{response.message}): #{params}")
        return {error: "#{response.code} (#{response.message}): #{params}"}
      end
    rescue Exception => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"#{e.message} for #{params}\n#{e.backtrace.join("\n\t")}")
      raise
    end
    nil
  end
end
