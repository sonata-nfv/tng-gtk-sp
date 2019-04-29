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
require 'securerandom'
require 'sinatra/activerecord'
require 'tng/gtk/utils/logger'
require 'tng/gtk/utils/application_controller'
require 'tng/gtk/utils/services'
require_relative '../services/messaging_service'

class SlicesController < Tng::Gtk::Utils::ApplicationController
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name

  @@began_at = Time.now.utc
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'START', message:"Started at #{@@began_at}")
  
  before { content_type :json}
  
  # VIMs
  get '/vims/?' do
    msg='#'+__method__.to_s
    LOGGER.info(component:LOGGED_COMPONENT, operation:msg, message:"Geting VIMs resources...")
    message_service = MessagingService.build('infrastructure.management.compute.list')
    @lock = Mutex.new
    @condition = ConditionVariable.new
    @call_id = SecureRandom.uuid
    message_service.queue.subscribe do |delivery_info, properties, payload|
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"delivery_info: #{delivery_info}\nproperties: #{properties}\npayload: #{payload}")
      @remote_response = payload
      @lock.synchronize { @condition.signal }
    end
    message_service.publish( '', @call_id)
    @lock.synchronize { @condition.wait(@lock) }
    parsed_payload = YAML.load(@remote_response)
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"parsed_payload: #{parsed_payload}")
    halt 200, {}, "{\"vim_list\":#{parsed_payload['vim_list'].to_json}, \"nep_list\":#{parsed_payload['nep_list'].to_json}}" if parsed_payload.is_a?(Hash)
    halt 500, {}, {error: "#{LOGGED_COMPONENT}#{msg}: Payload with resources not valid"}
  end
  
  # Networks
  post '/networks/?' do
    msg='#'+__method__.to_s
    LOGGER.info(component:LOGGED_COMPONENT, operation:msg, message:"Creating networks...")
    body = JSON.parse(request.body.read)
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"body=#{body}")
    message_service = MessagingService.build('infrastructure.service.network.create')
    @lock = Mutex.new
    @condition = ConditionVariable.new
    @call_id = SecureRandom.uuid
    message_service.queue.subscribe do |delivery_info, properties, payload|
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"delivery_info: #{delivery_info}\nproperties: #{properties}\npayload: #{payload}")
      @remote_response = payload
      @lock.synchronize { @condition.signal }
    end
    message_service.publish( build_creation_message(body[:instance_id], body[:vim_list]), @call_id)
    @lock.synchronize { @condition.wait(@lock) }
    parsed_payload = YAML.load(@remote_response)
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"parsed_payload: #{parsed_payload}")
    if parsed_payload.is_a?(Hash)
      # maybe should return 400?
      halt 200, {}, "{\"request_status\":\"#{parsed_payload['request_status']}\", \"message\":\"#{parsed_payload['message']}\"}" 
    end
    halt 500, {}, {error: "#{LOGGED_COMPONENT}#{msg}: Payload with resources not valid"}
  end
  
  delete '/networks/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Deleting networks...")
  end
  
  # WAN Networks
  post '/wan-networks/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Creating WAN networks...")
  end
  
  delete '/wan-networks/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Deleting WAN networks...")
  end
  
  private
  def build_creation_message(instance_id, vim_list)
    message = {}
    message['instance_id'] = instance_id
    message['vim_list'] = vim_list
    message.to_yaml
  end
  
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'STOP', message:"Ended at #{Time.now.utc}", time_elapsed:"#{Time.now.utc-began_at}")
end
