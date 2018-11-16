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
require 'sinatra'
require 'json'
require 'sinatra/activerecord'
require 'tng/gtk/utils/application_controller'
require 'tng/gtk/utils/services'
require_relative '../services/process_request_base'
require_relative '../services/process_request_service'
require_relative '../services/process_create_slice_instance_request'
require_relative '../services/process_terminate_slice_instance_request'

class RequestsController < Tng::Gtk::Utils::ApplicationController
  #register Sinatra::ActiveRecordExtension
  
  ERROR_REQUEST_CONTENT_TYPE={error: "Unsupported Media Type, just accepting 'application/json' HTTP content type for now."}
  ERROR_SERVICE_NOT_FOUND="Network Service with UUID '%s' was not found in the Catalogue."
  ERROR_PARSING_NS_DESCRIPTOR="There was an error parsing the NS descriptor with UUID '%s'."
  ERROR_CONNECTING_TO_CATALOGUE={error: "There was an error connecting to the Catalogue."}
  ERROR_EMPTY_BODY = <<-eos 
  The request was missing a body with:
     \tservice_uuid: the UUID of the service to be instantiated
     \trequest_type: can be CREATE_SERVICE (default), UPDATE_SERVICE or TERMINATE_SERVICE
     \tegresses: the list of required egresses (defaults to [])
     \tingresses: the list of required ingresses (defaults to [])
  eos
  #ERROR_SERVICE_UUID_IS_MISSING="Service UUID is a mandatory parameter (absent from the '%s' request)"
  ERROR_REQUEST_NOT_FOUND="Request with UUID '%s' was not found"
  
  # From http://gavinmiller.io/2016/the-safesty-way-to-constantize/
  STRATEGIES = {
    'CREATE_SERVICE': ProcessRequestService,
    'TERMINATE_SERVICE': ProcessRequestService,
    'CREATE_SLICE': ProcessCreateSliceInstanceRequest,
    'TERMINATE_SLICE': ProcessTerminateSliceInstanceRequest
  }

  before do 
    # STDERR.puts "INFO: RequestsController: ActiveRecord pool size=#{ActiveRecord::Base.connection.pool.size}"
    content_type :json
  end
  #after  {ActiveRecord::Base.clear_active_connections!}
  after  {ActiveRecord::Base.clear_all_connections!}

  # Accept service instantiation requests
  post '/?' do
    msg='RequestsController#post'
    halt_with_code_body(415, ERROR_REQUEST_CONTENT_TYPE.to_json) unless request.content_type =~ /^application\/json/

    body = request.body.read
    halt_with_code_body(400, ERROR_EMPTY_BODY.to_json) if body.empty?
    
    begin
      json_body = JSON.parse(body, quirks_mode: true, symbolize_names: true)
      json_body[:request_type] = 'CREATE_SERVICE' unless json_body.key?(:request_type)
      STDERR.puts "#{msg}: json_body=#{json_body}"
      STDERR.puts "#{msg}: RequestsController::STRATEGIES=#{RequestsController::STRATEGIES}"
    
      #chosen_strategy_class = choose_strategy(json_body)
      #STDERR.puts "#{msg}: going to call #{STRATEGIES[json_body[:request_type]]}.call with #{json_body.deep_symbolize_keys}"
      saved_request = strategy(json_body[:request_type]).call(json_body.deep_symbolize_keys)
    
      STDERR.puts "#{msg}: saved_request='#{saved_request.inspect}'"
      halt_with_code_body(400, {error: "Error saving request"}.to_json) if !saved_request
      # for the special case of CREATE_SLICE, the returned data structure is not an Hash
      halt_with_code_body(404, {error: saved_request[:error]}.to_json) if (saved_request && saved_request.is_a?(Hash) && saved_request.key?(:error))
      result = strategy(json_body[:request_type]).enrich_one(saved_request)
      STDERR.puts "#{msg}: result=#{result}"
      halt_with_code_body(201, result.to_json)
    rescue KeyError => e
      STDERR.puts "#{msg}: #{e.message} for #{params}"
      halt_with_code_body(404, {error: "Missing code to treat the '#{json_body[:request_type]}' request type"}.to_json)
    rescue ArgumentError => e
      STDERR.puts "#{msg}: #{e.message} for #{params}\n#{e.backtrace.join("\n\t")}"
      halt_with_code_body(404, {error: "#{e.message} for #{params}"}.to_json)
    rescue JSON::ParserError => e
      halt_with_code_body(400, {error: ERROR_PARSING_NS_DESCRIPTOR % params[:service_uuid]}.to_json)
    rescue StandardError => e
      halt_with_code_body(500, "#{e.message}\n#{e.backtrace.join("\n\t")}")
    end
  end
  
  # GETs a request, given an uuid
  get '/:request_uuid/?' do
    msg='RequestsController#get (single)'
    STDERR.puts "#{msg}: entered with params='#{params}'"
    captures=params.delete('captures') if params.key? 'captures'
    begin
      #single_request = Request.find(params[:request_uuid]).as_json
      single_request = ProcessRequestBase.find(params[:request_uuid], RequestsController::STRATEGIES)
      STDERR.puts "#{msg}: single_request='#{single_request}'"
      halt_with_code_body(404, {error: ERROR_REQUEST_NOT_FOUND % params[:request_uuid]}.to_json) if (!single_request || single_request.empty?)
      halt_with_code_body(200, single_request.to_json)
    rescue Exception => e
			ActiveRecord::Base.clear_active_connections!
      halt_with_code_body(404, {error: e.message}.to_json)
      raise
    end
  end

  # GET many requests
  get '/?' do
    msg='RequestsController#get (many)'
    captures=params.delete('captures') if params.key? 'captures'
    STDERR.puts "#{msg}: entered with params='#{params}'"
    
    # get rid of :page_size and :page_number
    page_number, page_size, sanitized_params = sanitize(params)
    STDERR.puts "#{msg}: page_number, page_size, sanitized_params=#{page_number}, #{page_size}, #{sanitized_params}"
    begin
      #       requests = Request.where(sanitized_params).limit(page_size).offset(page_number).order(updated_at: :desc)
      requests = ProcessRequestBase.search( page_number, page_size, RequestsController::STRATEGIES)
      STDERR.puts "#{msg}: requests='#{requests.inspect}'"
      headers 'Record-Count'=>requests.size.to_s, 'Content-Type'=>'application/json'
      halt 200, requests.to_json
      #halt 200, requests.to_json
    rescue ActiveRecord::RecordNotFound => e
      halt 200, '[]'
    rescue Exception => e
      STDERR.puts "#{msg}: Exception caught, ActiveRecord::Base.clear_active_connections!"
      STDERR.puts "#{msg}: #{e.message}\n#{e.backtrace.join("\n\t")}"
			ActiveRecord::Base.clear_active_connections!
      raise
    end
  end
  
  options '/?' do
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET,DELETE'      
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With'
    halt 200
  end
  
  # Callback for the tng-slice-mngr to notify the result of processing
  post '/:request_uuid/on-change/?' do
    msg='RequestsController#post /:request_uuid/on-change'
    STDERR.puts "#{msg}: entered, request_uuid=#{params[:request_uuid]}, params=#{params}"
    
    #halt 400, {}, {error: ERROR_EVENT_CONTENT_TYPE % request.content_type}.to_json unless request.content_type =~ /application\/json/
    begin
      body = request.body.read
      halt_with_code_body(400, "The callback is missing the event data") if body.empty?
      event_data = JSON.parse(body, quirks_mode: true, symbolize_names: true)

      event_data[:original_event_uuid] = params[:request_uuid]
      STDERR.puts "#{msg}: event_data=#{event_data}"
      result = ProcessCreateSliceInstanceRequest.process_callback(event_data)
      STDERR.puts "#{msg}: result=#{result}"
      halt 201, {}, result.to_json unless result.empty?
      halt 404, {}, {error: "Package processing UUID not found in event #{event_data}"}.to_json
    rescue JSON::ParserError, ActiveRecord::RecordNotFound, ArgumentError, NameError => e
      STDERR.puts "#{msg}: #{e.message} #{params}\n#{e.backtrace.join("\n\t")}"
      halt 400, {}, {error: e.message}.to_json
    end
  end  
  
  private
  def strategy(req_type)
    RequestsController::STRATEGIES.fetch(req_type.to_sym)
  end
  
  def halt_with_code_body(code, body)
    halt code, {'Content-Type'=>'application/json', 'Content-Length'=>body.length.to_s}, body
  end
  
  def validated_fields(params_keys)
    valid_fields = [:service_uuid, :status, :created_at, :updated_at]
    #logger.info(log_msg) {" keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}"}
    json_error 400, "GtkSrv: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []
  end
  
  def sanitize(params)
    params[:page_number] ||= ENV.fetch('DEFAULT_PAGE_NUMBER', 0)
    params[:page_size]   ||= ENV.fetch('DEFAULT_PAGE_SIZE', 100)
    page_number = params.delete(:page_number).to_i
    page_size = params.delete(:page_size).to_i
    return page_number, page_size, params
  end
  
  def symbolized_hash(hash)
    Hash[hash.map{|(k,v)| [k.to_sym,v]}]
  end
end
