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
require 'bunny'
require 'tng/gtk/utils/logger'
require_relative './messaging_service'

class CreateWANNetworksMessagingService  
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  QUEUE_NAME = 'infrastructure.service.wan.configure'

  def call(networks_request)
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"entered for networks_request=#{networks_request.inspect}")
    message_service = MessagingService.build(QUEUE_NAME)
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"message_service=#{message_service.inspect}")
    queue = message_service.queue
    unless queue
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"queue is nil")
      return
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"queue=#{queue.inspect}")
    queue.subscribe do |delivery_info, properties, payload|
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"delivery_info: #{delivery_info}\nproperties: #{properties}\npayload: #{payload}")
      # We know our own messages, so just skip them
      if properties[:app_id] == 'sonata.kernel.InfrAdaptor'
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Processing: properties[:app_id]: #{properties[:app_id]}")
        begin
          networks_request = SliceNetworksCreationRequest.find properties[:correlation_id]
          begin
            parsed_payload = JSON.parse(payload)
          rescue JSON::ParserError => e
            LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error parsing answer '#{payload}'")
            networks_request['status'] = 'ERROR'
            networks_request['error'] = "Error parsing answer '#{payload}'"
          end
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"parsed_payload: #{parsed_payload}")
          if parsed_payload['request_status']
            LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"request_status: #{parsed_payload['request_status']}")
            networks_request['status'] = parsed_payload['request_status']
            if parsed_payload['request_status'] == 'ERROR'
              networks_request['error'] = parsed_payload['message']
            end
            networks_request.save
            LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Just updated networks_request: #{networks_request.status}")
        rescue => e
          LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Could not find any Netwrok Creation record with id #{properties[:correlation_id]}")
        end
      end
    end
    message_service.publish( build_message(networks_request), networks_request.id)
  end
  
  private
  def build_message(obj)
    msg='#'+__method__.to_s
    message = {}
    message['service_instance_id'] = obj.instance_uuid
    message['wim_uuid'] = obj.wim_uuid
    message['vl_id'] = obj.vl_id
    message['bidirectional'] = obj.bidirectional
    if obj.qos
      begin
        message['qos'] = JSON.parse(obj.qos)
      rescue JSON::ParserError => e
        LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error parsing QOS '#{obj.qos}'")
        message['qos'] = ''
      end
    else
      message['qos'] = ''
    end
    begin
      message['ingress'] = JSON.parse(obj.ingress)
    rescue JSON::ParserError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error parsing ingress '#{obj.ingress}'")
      message['ingress'] = '{}'
    end
    begin
      message['egress'] = JSON.parse(obj.egress)
    rescue JSON::ParserError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error parsing egress '#{obj.egress}'")
      message['egress'] = '{}'
    end
    return message.to_yaml
  end
end



