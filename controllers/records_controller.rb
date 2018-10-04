## SONATA - Gatekeeper
##
## Copyright (c) 2015 SONATA-NFV [, ANY ADDITIONAL AFFILIATION]
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
## Neither the name of the SONATA-NFV [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote 
## products derived from this software without specific prior written 
## permission.
## 
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through 
## the Horizon 2020 and 5G-PPP programmes. The authors would like to 
## acknowledge the contributions of their colleagues of the SONATA 
## partner consortium (www.sonata-nfv.eu).
# frozen_string_literal: true
# encoding: utf-8
require 'sinatra'
require 'json'
require 'logger'
require 'securerandom'
require 'application_controller'

class RecordsController < ApplicationController

  ERROR_RECORD_NOT_FOUND="No record with UUID '%s' was found"

  @@began_at = Time.now.utc
  settings.logger.info(self.name) {"Started at #{@@began_at}"}
  before { content_type :json}
  
  get '/services/?' do 
    msg='RecordsController.get /services (many)'
    captures=params.delete('captures') if params.key? 'captures'
    STDERR.puts "#{msg}: params=#{params}"
    result = FetchServiceRecordsService.call(symbolized_hash(params))
    STDERR.puts "#{msg}: result=#{result}"
    halt 404, {}, {error: "No records fiting the provided parameters ('#{params}') were found"}.to_json if result.to_s.empty? # covers nil
    halt 200, {}, result.to_json
  end
  
  get '/services/:record_uuid/?' do 
    msg='RecordsController.get /services (single)'
    captures=params.delete('captures') if params.key? 'captures'
    STDERR.puts "#{msg}: params['record_uuid']='#{params['record_uuid']}'"
    result = FetchServiceRecordsService.call(uuid: params['record_uuid'])
    STDERR.puts "#{msg}: result=#{result}"
    halt 404, {}, {error: ERROR_RECORD_NOT_FOUND % params['record_uuid']}.to_json if result == {}
    halt 200, {}, result.to_json
  end
  
  get '/functions/?' do 
    msg='RecordsController.get /functions (many)'
    captures=params.delete('captures') if params.key? 'captures'
    STDERR.puts "#{msg}: params=#{params}"
    result = FetchFunctionRecordsService.call(symbolized_hash(params))
    STDERR.puts "#{msg}: result=#{result}"
    halt 404, {}, {error: "No records fiting the provided parameters ('#{params}') were found"}.to_json if result.to_s.empty? # covers nil
    halt 200, {}, result.to_json
  end
  
  get '/functions/:record_uuid/?' do 
    msg='RecordsController.get /functions (single)'
    captures=params.delete('captures') if params.key? 'captures'
    STDERR.puts "#{msg}: params['record_uuid']='#{params['record_uuid']}'"
    result = FetchFunctionRecordsService.call(uuid: params['record_uuid'])
    STDERR.puts "#{msg}: result=#{result}"
    halt 404, {}, {error: ERROR_RECORD_NOT_FOUND % params['record_uuid']}.to_json if result == {}
    halt 200, {}, result.to_json
  end

  options '/?' do
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET,DELETE'      
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With'
    halt 200
  end
    
  private
  def uuid_valid?(uuid)
    return true if (uuid =~ /[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}/) == 0
    false
  end
  
  def symbolized_hash(hash)
    Hash[hash.map{|(k,v)| [k.to_sym,v]}]
  end
end
