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
require_relative '../models/infrastructure_request'
require_relative '../services/fetch_vim_resources_messaging_service'

class SlicesController < Tng::Gtk::Utils::ApplicationController
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name

  @@began_at = Time.now.utc
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'START', message:"Started at #{@@began_at}")
  
  before { content_type :json}
  
  # VIMs
  get '/vims/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Geting VIMs resources...")
=begin
    vims_request = SliceVimResourcesRequest.create
    unless vims_request
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error creating SliceVimResourcesRequest")
      halt 500, {}, "Error creating SliceVimResourcesRequest"
    end
      
    ms=FetchVimResourcesMessagingService.new
    ms.call(vims_request)
    loop do
      break if ms.done
    end
    result = vims_request.reload.as_json
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result=#{result}")
=end
    message_service = MessagingService.build('infrastructure.management.compute.list')
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"message_service: #{message_service}")
    @lock = Mutex.new
    @condition = ConditionVariable.new
    @call_id = SecureRandom.uuid
    message_service.queue.subscribe do |delivery_info, properties, payload|
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"delivery_info: #{delivery_info}\nproperties: #{properties}\npayload: #{payload}")
      #if properties[:correlation_id] == @call_id
      #unless properties[:app_id] == 'tng-gtk-sp'
        @remote_response = payload
        @lock.synchronize { @condition.signal }
        #end
    end
    message_service.publish( '', @call_id)
    @lock.synchronize { @condition.wait(@lock) }
    parsed_payload = YAML.load(@remote_response)
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"parsed_payload: #{parsed_payload}")
    halt 200, {}, "{\"vim_list\":#{parsed_payload['vim_list']}, \"nep_list\":#{parsed_payload['nep_list']}}" if parsed_payload.is_a?(Hash)
    halt 500, {}, {error: "#{LOGGED_COMPONENT}#{msg}: Payload with resources not valid"}
  end
  
  # Networks
=begin
  post '/networks/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Creating networks...")
    networks_request = SliceNetworksCreationRequest.create(instance_uuid: params['instance_id'], vim_list: params['vim_list'])
    unless networks_request
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error creating SliceNetworksCreationRequest")
      halt 500, {}, "Error creating SliceNetworksCreationRequest"
    end
    CreateNetworksMessagingService.new.call(networks_request)
    result = networks_request.reload.as_json
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result=#{result}")
    halt 200, {}, "{\"instance_id\":\"#{result['instance_id']}\", \"vim_list\":#{result['vim_list']}}"
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
=end
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'STOP', message:"Ended at #{Time.now.utc}", time_elapsed:"#{Time.now.utc-began_at}")
end
