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

class MessagingService  
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  TOPIC = 'son-kernel'
  GK_QUEUE_PREFIX = 'gk.'
  APP_ID = 'tng-gtk-sp'
  MQSERVER_URL = ENV.fetch('MQSERVER_URL', '')
  if MQSERVER_URL == ''
    LOGGER.error(component:LOGGED_COMPONENT, operation:'starting', message:"No MQServer URL has been defined")
    raise ArgumentError.new('No MQServer URL has been defined') 
  end

  attr_accessor :exchange, :queue_name, :queue
  def initialize(exchange, queue_name, queue)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Initializing with exchange=#{exchange.inspect}, queue_name=#{exchange}, queue=#{exchange.inspect}")
    @exchange, @queue_name, @queue = exchange, queue_name, queue
  end
  
  def self.build(queue_name)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"queue_name= #{queue_name}")
    begin
      channel = Bunny.new(MQSERVER_URL, automatically_recover: false).start.create_channel
    rescue Bunny::TCPConnectionFailed => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Connection to #{MQSERVER_URL} failed")
      return nil
    end
    exchange = channel.topic( TOPIC, auto_delete: false)
    queue = channel.queue(GK_QUEUE_PREFIX+queue_name).bind(exchange, routing_key: queue_name) 
    new exchange, queue_name, queue
  end
  
  def publish(message, correlation_id)
    exchange.publish( message, content_type:'text/yaml', routing_key: queue_name, correlation_id: correlation_id, reply_to: queue_name, app_id: APP_ID)
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



