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

class ProcessTerminateSliceInstanceRequest < ProcessRequestBase
  
  NO_SLM_URL_DEFINED_ERROR='The SLM_URL ENV variable needs to be defined and pointing to the Slice Manager component, where to request the termination of a Network Slice'
  SLM_URL = ENV.fetch('SLM_URL', '')
  if SLM_URL == ''
    STDERR.puts "%s - %s: %s" % [Time.now.utc.to_s, self.name, NO_SLM_URL_DEFINED_ERROR]
    raise ArgumentError.new(NO_SLM_URL_DEFINED_ERROR) 
  end
  SLICE_INSTANCE_CHANGE_CALLBACK_URL = ENV.fetch('SLICE_INSTANCE_CHANGE_CALLBACK_URL', 'http://tng-gtk-sp:5000/requests')
  
  def self.call(params)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: params=#{params}"
    begin
      valid = valid_request?(params)
      if (valid && valid.is_a?(Hash) && valid.key?(:error) )
        STDERR.puts "#{msg}: validation failled with error #{valid[:error]}"
        return valid
      end
      
      enriched_params = enrich_params(params)
      STDERR.puts "#{msg}: enriched_params params=#{enriched_params}"
      
      termination_request = Request.create(enriched_params)
      STDERR.puts "#{msg}: termination_request=#{termination_request.inspect} (class #{termination_request.class})"
      unless termination_request
        STDERR.puts "#{msg}: Failled to create termination request"
        return {error: "Failled to create termination request for slice template '#{params[:nstId]}'"}
      end
      # pass it to the Slice Manager
      # {"nstId":"3a2535d6-8852-480b-a4b5-e216ad7ba55f", "name":"Testing", "description":"Test desc"}
      # the user callback is saved in the request
      enriched_params[:callback] = "#{SLICE_INSTANCE_CHANGE_CALLBACK_URL}/#{termination_request['id']}/on-change"
      request = terminate_slice(enriched_params)
      STDERR.puts "#{msg}: request=#{request}"
      if (request && request.is_a?(Hash) && request.key?(:error))
        saved_req=Request.find(termination_request['id'])
        STDERR.puts "#{msg}: saved_req=#{saved_req.inspect}"
        saved_req.update(status: 'ERROR', error: request[:error])
        return saved_req.as_json
      end
      termination_request
    rescue StandardError => e
      STDERR.puts "#{msg}: (#{e.class}) #{e.message}\n#{e.backtrace.split('\n\t')}"
      return {error: "#{e.message}"}
    end
  end
  
  # "/api/nsilcm/v1/nsi/on-change"
  # @app.route(API_ROOT+API_NSILCM+API_VERSION+API_NSI+'/update_NSIservinstance', methods=['POST'])
  # GET http://tng-slice-mngr:5998/api/nst/v1/descriptors
  def self.process_callback(event)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: event=#{event}"
    result, user_callback = save_result(event)
    notify_user(result, user_callback) unless user_callback.to_s.empty?
    STDERR.puts "#{msg}: result=#{result}"
    result
  end
  
  def self.enrich_one(request)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: request=#{request.inspect} (class #{request.class})"
    request
  end
  
  private  
  def self.save_result(event)
    msg=self.name+'.'+__method__.to_s
    original_request = Request.find(event[:original_event_uuid]) #.as_json
    STDERR.puts "#{msg}: original request = #{original_request.inspect}"
    body = JSON.parse(request.body.read, quirks_mode: true, symbolize_names: true)
    original_request['status'] = body[:status]
    original_request.save
    [original_request.as_json, body[:callback]]
  end
  
  def self.notify_user(result, user_callback)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: entered, result=#{result}, user_callback=#{user_callback}"
    
    uri = URI.parse(user_callback)

    # Create the HTTP objects
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri, {'Content-Type': 'text/json'})
    request.body = result.to_json

    # Send the request
    begin
      response = http.request(request)
      STDERR.puts "#{msg}: response=#{response}"
      case response
      when Net::HTTPSuccess, Net::HTTPCreated
        body = response.body
        STDERR.puts "#{msg}: #{response.code} body=#{body}"
        return JSON.parse(body, quirks_mode: true, symbolize_names: true)
      else
        return {error: "#{response.message}"}
      end
    rescue Exception => e
      STDERR.puts "%s - %s: %s", [Time.now.utc.to_s, msg, "Failled to post to user's callback #{user_callback} with message #{e.message}"]
    end
    nil
  end

  def self.valid_request?(params)
    msg=self.name+'.'+__method__.to_s
    # { "request_type":"CREATE_SLICE", "nstId":"3a2535d6-8852-480b-a4b5-e216ad7ba55f", "name":"Testing", "description":"Test desc", "slice_instance_ready_callback":"http://..."}
    # if params include a Network Slice Template UUID
    # template existense is tested within the SLM
    # GET http://tng-slice-mngr:5998/api/nst/v1/descriptors

    true
    # else {error: ''}
  end
  
  def self.enrich_params(params)
    msg=self.name+'.'+__method__.to_s
    STDERR.puts "#{msg}: params=#{params}"
    params
  end
  
  def self.terminate_slice(params)
    msg=self.name+'.'+__method__.to_s
    # POST http://tng-slice-mngr:5998/api/nsilcm/v1/nsi/<nsiId>/terminate, with body {'callback':'http://...'}
    # curl -i -H "Content-Type:application/json" -X POST -d '{"terminateTime": "_time_", "callback":"URL_with_callback_request"}' http://{base_url}:5998/api/nsilcm/v1/nsi/<nsiId>/terminate
    # $ http POST :4567/wtf p1=one p2=two
    # body={"p1": "one", "p2": "two"}
    # params={"xyz"=>"wtf"}
    site = "#{SLM_URL}/nsilcm/v1/nsi/#{params[:instance_uuid]}/terminate"
    STDERR.puts "#{msg}: params=#{params} site=#{site}"
    uri = URI.parse(site)

    # Create the HTTP objects
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri, {'Content-Type': 'text/json'})
    request.body = { terminateTime: '', callback: params[:callback]}.to_json

    # Send the request
    begin
      response = http.request(request)
      STDERR.puts "#{msg}: response=#{response}"
      case response
      when Net::HTTPSuccess, Net::HTTPCreated
        body = response.body
        STDERR.puts "#{msg}: #{response.code} body=#{body}"
        return JSON.parse(body, quirks_mode: true, symbolize_names: true)
      else
        return {error: "#{response.code} (#{response.message}): #{params}"}
      end
    rescue Exception => e
      STDERR.puts "%s - %s: %s" % [Time.now.utc.to_s, msg, e.message]
      raise
    end
    nil
  end
  
end
