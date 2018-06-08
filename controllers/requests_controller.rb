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
#require_relative '../services/fetch_nsd_service'
#require_relative '../services/fetch_vnfds_service'

class RequestsController < ApplicationController
  #register Sinatra::ActiveRecordExtension
  
  ERROR_REQUEST_CONTENT_TYPE={error: "Just accepting 'application/json' HTTP content type for now."}
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
  ERROR_SERVICE_UUID_IS_MISSING="Service UUID is a mandatory parameter (absent from the '%s' request)"
  #         params['callback'] = kpis_url+'/service-instantiation-time'
  
  before { content_type :json}

  # Accept service instantiation requests
  post '/?' do
    halt_with_code_body(400, ERROR_REQUEST_CONTENT_TYPE.to_json) unless request.content_type =~ /^application\/json/

    body = request.body.read
    halt_with_code_body(400, ERROR_EMPTY_BODY.to_json) if body.empty?
    params = JSON.parse(body, quirks_mode: true, symbolize_names: true)
    halt_with_code_body(400, ERROR_SERVICE_UUID_IS_MISSING % params) unless params.key?(:service_uuid)
    
    begin
      saved_request = ProcessRequestService.call(params.merge({user_data: request.env['5gtango.user.data']}))
      halt_with_code_body(201, saved_request.to_json)
    rescue ArgumentError => e
      halt_with_code_body(404, {error: e.message}.to_json)
    rescue JSON::ParserError => e
      halt_with_code_body(400, {error: ERROR_PARSING_NS_DESCRIPTOR % params[:service_uuid]}.to_json)
    rescue StandardError => e
      halt_with_code_body(500, ERROR_CONNECTING_TO_CATALOGUE)
    end
  end
  
  private
  def halt_with_code_body(code, body)
    halt code, {'Content-Type'=>'application/json', 'Content-Length'=>body.length.to_s}, body
  end
end
