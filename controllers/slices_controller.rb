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
require_relative '../models/infrastructure_request'
require_relative '../services/messaging_service'
require_relative '../services/fetch_vim_resources_messaging_service'
require_relative '../services/fetch_wim_resources_messaging_service'
require_relative '../services/create_networks_messaging_service'
require_relative '../services/delete_networks_messaging_service'
require_relative '../services/create_wan_networks_messaging_service'

SLEEPING_TIME = 2 # seconds
NUMBER_OF_ITERATIONS = 40

class SlicesController < Tng::Gtk::Utils::ApplicationController
  set :database_file, 'config/database.yml'
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name

  @@began_at = Time.now.utc
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'START', message:"Started at #{@@began_at}")
  MQSERVER_URL = ENV.fetch('MQSERVER_URL', '')
  if MQSERVER_URL == ''
    LOGGER.error(component:LOGGED_COMPONENT, operation:'starting', message:"No MQServer URL has been defined")
    raise ArgumentError.new('No MQServer URL has been defined') 
  end
  
  before { content_type :json}
  
  # VIMs
  get '/vims/?' do
    msg='#'+__method__.to_s
    LOGGER.info(component:LOGGED_COMPONENT, operation:msg, message:"Geting VIMs resources...")
    @vim_request=SliceVimResourcesRequest.create
    FetchVimResourcesMessagingService.new.call @vim_request
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"@vim_request.vim_list=#{@vim_request.vim_list} @vim_request.nep_list=#{@vim_request.nep_list}")
    times = NUMBER_OF_ITERATIONS
    result = nil
    loop do
      result = SliceVimResourcesRequest.find @vim_request.id
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"times=#{times} result.vim_list=#{result.vim_list} result.nep_list=#{result.nep_list}")
      times -= 1
      break if (times == 0 || result.vim_list != '[]' || result.nep_list != '[]')
      sleep SLEEPING_TIME
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result: #{result.inspect}")
    halt 200, {}, "{\"vim_list\":#{result.vim_list}, \"nep_list\":#{result.nep_list}}"
  end
  
  get '/wims/?' do
    msg='#'+__method__.to_s
    LOGGER.info(component:LOGGED_COMPONENT, operation:msg, message:"Geting WIM resources...")
    @wim_request=SliceWimResourcesRequest.create
    FetchWimResourcesMessagingService.new.call @wim_request
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"@wim_request.wim_list=#{@wim_request.wim_list}")
    times = NUMBER_OF_ITERATIONS
    result = nil
    loop do
      result = SliceWimResourcesRequest.find @wim_request.id
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"times=#{times} result.wim_list=#{result.wim_list}")
      times -= 1
      break if (times == 0 || result.wim_list != '[]')
      sleep SLEEPING_TIME
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result: #{result.inspect}")
    halt 200, {}, "{\"wim_list\":#{result.wim_list}}"
  end
  
  # Networks
  post '/networks/?' do
    msg='#'+__method__.to_s
    LOGGER.info(component:LOGGED_COMPONENT, operation:msg, message:"Creating networks...")
    original_body = request.body.read
    begin
      body = JSON.parse(original_body)
    rescue JSON::ParserError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error parsing network creation request #{original_body}")
      halt 404, {}, {error:"Error parsing network creation request #{original_body}"}.to_json
    end
    network_creation = SliceNetworksCreationRequest.new
    network_creation['instance_uuid']= body.delete 'instance_id'
    network_creation['vim_list']= body['vim_list'].to_json
    halt 500, {}, {error: "Problem saving request #{original_body} with errors #{network_creation.errors.messages}"}.to_json unless network_creation.save
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Saved network_creation=#{network_creation.as_json}")
    CreateNetworksMessagingService.new.call network_creation
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"network_creation.status=#{network_creation.status}")
    times = NUMBER_OF_ITERATIONS
    result = nil
    loop do
      result = SliceNetworksCreationRequest.find network_creation.id
      times -= 1
      break if (times == 0 || result.status == 'COMPLETED' || result.status == 'ERROR')
      sleep SLEEPING_TIME
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result: #{result.as_json}")
    halt 201, {}, result.as_json.to_json 
  end
  
  delete '/networks/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Deleting networks...")
    begin
      original_body = request.body.read
      body = JSON.parse(original_body)
    rescue JSON::ParserError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error parsing network deletion request #{original_body}")
      hast 404, {}, {error:"Error parsing network deletion request #{original_body}"}.to_json
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"body=#{body}")
    network_deletion = SliceNetworksDeletionRequest.new
    network_deletion['instance_uuid']= body.delete 'instance_id'
    network_deletion['vim_list']= body['vim_list'].to_json
    halt 500, {}, {error: "Problem saving request #{original_body} with errors #{network_deletion.errors.messages}"}.to_json unless network_deletion.save
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Saved network_deletion=#{network_deletion.as_json}")
    DeleteNetworksMessagingService.new.call network_deletion
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"network_deletion.status=#{network_deletion.status}")
    times = NUMBER_OF_ITERATIONS
    result = nil
    loop do
      result = SliceNetworksDeletionRequest.find network_deletion.id
      times -= 1
      break if (times == 0 || result.status == 'COMPLETED' || result.status == 'ERROR')
      sleep SLEEPING_TIME
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result: #{result.inspect}")
    halt 201, {}, result.as_json.to_json 
  end
  
  # WAN Networks
  post '/wan-networks/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Creating WAN networks...")
    original_body = request.body.read
    begin
      body = JSON.parse(original_body)
    rescue JSON::ParserError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error parsing WAN network creation request #{original_body}")
      halt 404, {}, {error:"Error parsing WAN network creation request #{original_body}"}.to_json
    end
    network_creation = SliceWANNetworksCreationRequest.new
    network_creation['instance_uuid']= body['instance_uuid']
    network_creation['wim_uuid']= body['wim_uuid']
    network_creation['vl_id']= body['vl_id']
    network_creation['qos']= body['qos']
    network_creation['egress']= body['egress']
    network_creation['ingress']= body['ingress']
    network_creation['bidirectional']= body['bidirectional']
    halt 500, {}, {error: "Problem saving request #{original_body} with errors #{network_creation.errors.messages}"}.to_json unless network_creation.save
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Saved network_creation=#{network_creation.as_json}")
    CreateWANNetworksMessagingService.new.call network_creation
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"network_creation.status=#{network_creation.status}")
    times = NUMBER_OF_ITERATIONS
    result = nil
    loop do
      result = SliceWANNetworksCreationRequest.find network_creation.id
      times -= 1
      break if (times == 0 || result.status == 'COMPLETED' || result.status == 'ERROR')
      sleep SLEEPING_TIME
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result: #{result.as_json}")
    halt 201, {}, result.as_json.to_json 
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
