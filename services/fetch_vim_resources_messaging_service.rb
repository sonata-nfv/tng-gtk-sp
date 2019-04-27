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

class FetchVimResourcesMessagingService  
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  QUEUE_NAME = 'infrastructure.management.compute.list'

  def call(vims_request)
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"entered for vims_request=#{vims_request.inspect}")
    message_service = MessagingService.build(QUEUE_NAME)
    queue = message_service.queue
    unless queue
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"queue is nil")
      return
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"queue=#{queue.inspect}")
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Does queue has a subscribe method? #{queue.respond_to?(:subscribe)}")
    queue.subscribe do |delivery_info, properties, payload|
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"delivery_info: #{delivery_info}\nproperties: #{properties}\npayload: #{payload}")
      # We know our own messages, so just skip them
      if properties[:app_id] == 'tng-gtk-sp'
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Leaving, we know our own messages, so just skip them...")
      else
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Processing: properties[:app_id]: #{properties[:app_id]}")
      
        # {vim_list: [{vim_uuid: String, type: String, vim_city: String, vim_domain: String, vim_name: String, vim_endpoint: String, memory_total: int, memory_used: int, core_total: int, core_used: int}], nep_list: [{nep_uuid: String, type: String, nep_name: String}]}
        parsed_payload = YAML.load(payload)
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"parsed_payload: #{parsed_payload}")
        if parsed_payload['vim_list']
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"vim_list: #{parsed_payload['vim_list']}")
          vims_request.update(vim_list: parsed_payload['vim_list']) #.to_yaml.gsub('---\n', ''))
        end
        if parsed_payload['nep_list']
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"nep_list: #{parsed_payload['nep_list']}")
          vims_request.update(nep_list: parsed_payload['nep_list']) #.to_yaml.gsub('---\n', ''))
        end
      end
    end
    message_service.publish( '', vims_request.id)
  end
  
  private
  def self.notify_user(params)
    msg='.'+__method__.to_s
    uri = URI.parse(params['callback'])

    # Create the HTTP objects
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request.body = params.to_json
    request['Content-Type'] = 'application/json'

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
        return {error: "#{response.message}"}
      end
    rescue Exception => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Failled to post to user's callback #{user_callback} with message #{e.message}")
    end
    nil
  end
end



