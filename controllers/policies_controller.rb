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

class PoliciesController < ApplicationController
  ERROR_REQUEST_CONTENT_TYPE={error: "Unsupported Media Type, just accepting 'application/json' HTTP content type for now."}
  ERROR_EMPTY_BODY = <<-eos 
  The request was missing a body with:
     \tpolicy: prioritise | load balanced | fill first 
     \tdatacenters: [] | [location_1, location_2, ...]
  eos
  ERROR_POLICY_IS_MISSING="Policy is a mandatory parameter (absent from the '%s' request)"
  ERROR_PARSING_POLICY="There was an error parsing the placement policy '%s'."
  ERROR_POLICY_NOT_FOUND="Policy '%s' was not found"

  # Accept service instantiation requests
  post '/placement/?' do
    msg='PoliciesController.post'
    halt_with_code_body(415, ERROR_REQUEST_CONTENT_TYPE.to_json) unless request.content_type =~ /^application\/json/

    body = request.body.read
    halt_with_code_body(400, ERROR_EMPTY_BODY.to_json) if (!body || body.empty?)
    params = JSON.parse(body, quirks_mode: true, symbolize_names: true)
    halt_with_code_body(400, ERROR_POLICY_IS_MISSING % params) unless params.key?(:policy)
    
    begin
      added_policy = ProcessPlacementPolicyService.add(params.deep_symbolize_keys)
      STDERR.puts "#{msg}: added_policy='#{added_policy}'"
      halt_with_code_body(400, {error: "Placement policy '#{params[:policy]}' not added"}.to_json) if (!added_policy || added_policy.empty?)
      halt_with_code_body(404, {error: added_policy[:error]}.to_json) if (added_policy.is_a?(Hash) && added_policy.key?(:error))
      halt_with_code_body(200, added_policy.to_json)
    rescue ArgumentError => e
      halt_with_code_body(404, {error: e.message}.to_json)
    rescue JSON::ParserError => e
      halt_with_code_body(400, {error: ERROR_PARSING_POLICY % params}.to_json)
    rescue StandardError => e
      halt_with_code_body(500, e.message)
    end
  end
  
  # GETs a request, given an uuid
  get '/placement/:placement_policy_uuid/?' do
    msg='PoliciesController.get (single)'
    captures=params.delete('captures') if params.key? 'captures'
    begin
      single_request = ProcessPlacementPolicyService.call(params[:placement_policy_uuid])
      halt_with_code_body(404, {error: ERROR_POLICY_NOT_FOUND % params[:placement_policy_uuid]}.to_json) if (!single_request || single_request.empty?)
      halt_with_code_body(200, single_request.to_json)
    rescue Exception => e
      halt_with_code_body(404, {error: e.message}.to_json)
    end
  end

  # GET many requests
  get '/placement/?' do
    msg='PoliciesController.get (many)'
    captures=params.delete('captures') if params.key? 'captures'
    
    # get rid of :page_size and :page_number
    page_number, page_size, sanitized_params = sanitize(params)
    begin
      requests = ProcessPlacementPolicyService.call(params.deep_symbolize_keys)
      headers 'Record-Count'=>requests.size.to_s, 'Content-Type'=>'application/json'
      halt 200, requests.to_json
    rescue ActiveRecord::RecordNotFound => e
      halt 200, '[]'
    end
  end
  
  options '/?' do
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET,DELETE'      
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With'
    halt 200
  end
  
  private
  def halt_with_code_body(code, body)
    halt code, {'Content-Type'=>'application/json', 'Content-Length'=>body.length.to_s}, body
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
