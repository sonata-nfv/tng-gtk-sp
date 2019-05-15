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
  @@message_service = MessagingService.build(QUEUE_NAME)
  
  def call(vims_request)
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"entered for vims_request=#{vims_request.inspect}")
    queue = @@message_service.queue
    unless queue
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Got nill queue from Messaging service")
      return
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"queue=#{queue.inspect}")
    queue.subscribe do |delivery_info, properties, payload|
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"delivery_info: #{delivery_info}\nproperties: #{properties}\npayload: #{payload}")
      # We know our own messages, so just skip them
      unless properties[:app_id] == 'tng-gtk-sp'
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Processing: properties[:app_id]: #{properties[:app_id]}")
        parsed_payload = YAML.load(payload)
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"parsed_payload: #{parsed_payload}")
        vim_request = SliceVimResourcesRequest.find_by(id: properties[:correlation_id])
        if (parsed_payload['vim_list'] || parsed_payload['nep_list'])
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"vim_list: #{parsed_payload['vim_list']}")
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"nep_list: #{parsed_payload['nep_list']}")
          begin
            vim_request['vim_list'] = parsed_payload['vim_list'].to_json
            vim_request['nep_list'] = parsed_payload['nep_list'].to_json
            vim_request['status'] = 'COMPLETED'
            vim_request.save
            LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"vims_request: #{vim_request.inspect} ")
          rescue Exception => e
            LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"vims_request_error: #{e.message} #{e.backtrace.inspect} ")
          end
        end
      end
    end
    @@message_service.publish('', vims_request.id)
  end
end



