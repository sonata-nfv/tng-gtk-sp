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

class MessagePublishingService  
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  ERROR_VNFS_ARE_MANDATORY='VNFs parameter is mandatory'
  ERROR_VNF_CATALOGUE_URL_NOT_FOUND='VNF Catalogue URL not found in the ENV.'
  MQSERVER_URL = ENV.fetch('MQSERVER_URL', '')
  @@queues = {
    create_service: 'service.instances.create',
    terminate_service: 'service.instance.terminate',
    scale_service: 'service.instance.scale'
  }
  if MQSERVER_URL == ''
    LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"No MQServer URL has been defined")
    raise ArgumentError.new('No MQServer URL has been defined') 
  end

  def self.call(message, queue_symbol, correlation_id)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"message=#{message}, queue_symbol=#{queue_symbol}, correlation_id=#{correlation_id}")
    unless @@queues.keys.include? queue_symbol
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Queue must be one of :#{@@queues.keys.join(', :')}")
      raise ArgumentError.new("Queue must be one of :#{@@queues.keys.join(', :')}") 
    end
    if correlation_id == ''
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"No correlation has been given")
      raise ArgumentError.new('No correlation has been given') 
    end

    begin
      channel = Bunny.new(MQSERVER_URL, automatically_recover: false).start.create_channel
    rescue Bunny::TCPConnectionFailed => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Connection to #{MQSERVER_URL} failed")
      return nil
    end
    
    exchange = channel.topic("son-kernel", auto_delete: false)
    # So on the third line, the name of your queue should be gk.service.instances.create and the routing key should be service.instances.create. So there you need a change.
    #queue = channel.queue(@@queues[queue_symbol], auto_delete: true).bind(exchange, routing_key: @@queues[queue_symbol])
    #queue = channel.queue('gk.'+@@queues[queue_symbol], auto_delete: true).bind(exchange, routing_key: @@queues[queue_symbol])
    queue = channel.queue('gk.'+@@queues[queue_symbol]).bind(exchange, routing_key: @@queues[queue_symbol])
    self.send(:"#{@@queues[queue_symbol].gsub('.','_')}", queue: queue)
    # routing_key and reply_to should be the same value as routing_key on the third line
    # published = exchange.publish( message, content_type:'text/yaml', routing_key: queue.name, correlation_id: correlation_id, reply_to: queue.name, app_id: 'tng-gtk-sp')
    published = exchange.publish( message, content_type:'text/yaml', routing_key: @@queues[queue_symbol], correlation_id: correlation_id, reply_to: @@queues[queue_symbol], app_id: 'tng-gtk-sp')
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"published=#{published.inspect}")
    published
  end  
  
  private
  def self.service_instances_create(queue:)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"entered")
    queue.subscribe do |delivery_info, properties, payload|
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"delivery_info: #{delivery_info}\nproperties: #{properties}\npayload: #{payload}")
      begin
        # We know our own messages, so just skip them
        if properties[:app_id] == 'tng-gtk-sp'
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"leaving, we know our own messages, so just skip them...")
        else
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"properties[:app_id]: #{properties[:app_id]}")
      
          # We're interested in app_id == 'son-plugin.slm'
          parsed_payload = YAML.load(payload)
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"parsed_payload: #{parsed_payload}")
          status = parsed_payload['status']
          if status
            LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"status: #{status}")
            begin
              request = Request.find(properties[:correlation_id])
            ensure
              ActiveRecord::Base.clear_active_connections!
            end
            
            unless request
              LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"request #{properties[:correlation_id]} not found")
            else
              LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"status #{request['status']} updated to #{status}")
              request['status']=status
              if parsed_payload['error']
                request['error'] = parsed_payload['error']
              else
                if parsed_payload.key?('nsr')
                  # if this is a final answer, there'll be an NSR
                  service_instance = parsed_payload['nsr']
                  if service_instance.key?('id')
                    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"request['instance_uuid']='#{service_instance['id']}'")
                    request['instance_uuid'] = service_instance['id']
                  else
                    LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"no service instance uuid")
                  end
                end
              end
              request.save
              LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"leaving with request #{request.inspect}")
              notify_user(request.as_json) unless request['callback'].empty?
            end
          end
        end
      rescue Exception => e
        LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"#{e.message} (#{e.class}):#{e.backtrace.split('\n\t')}")
      end
    end
  end
  
  # Terminate
  # Request
  # To terminate a running service, send a message on the service.instance.terminate topic. This message requires the following header fields:
  #    app_id: to indicate the sender of the message
  #    correlation_id: a correlation id for the message
  #    reply_to: the topic on which the sender expects a response, in this case service.instances.create
  # The payload of the request is a yaml encoded dictionary that should include the following fields:
  #    instance_id : the service instance id of the service that needs to be terminated
  def self.service_instance_terminate(queue:)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"entered")
    queue.subscribe do |delivery_info, properties, payload|
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"delivery_info: #{delivery_info}\nproperties: #{properties}\npayload: #{payload}")
      begin

        # We know our own messages, so just skip them
        if properties[:app_id] == 'tng-gtk-sp'
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"leaving, we know our own messages, so just skip them...")
        else
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"properties[:app_id]: #{properties[:app_id]}")
      
          # We're interested in app_id == 'son-plugin.slm'
          parsed_payload = YAML.load(payload)
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"parsed_payload: #{parsed_payload}")
          status = parsed_payload['status']
          unless status
            LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"no status")
          else
            LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"status: #{status}")
            begin
              request = Request.find(properties[:correlation_id])
            ensure
              ActiveRecord::Base.clear_active_connections!
            end
            
            unless request
              LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"request '#{properties[:correlation_id]}' not found")
            else
              LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"status '#{request['status']}' updated to '#{status}'")
              request['status']=status
              if parsed_payload['error']
                request['error'] = parsed_payload['error']
                LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"recorded error '#{request['error']}'")
              end
              request.save
              LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"request #{request} saved")
              notify_user(request.as_json) unless request['callback'].empty?
            end
          end
        end
      rescue Exception => e
        LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"#{e.message} (#{e.class}): #{e.backtrace.split('\n\t')}")
      end
    end
  end
  
  def self.service_instance_scale(queue:)
    msg='.'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"entered")
    queue.subscribe do |delivery_info, properties, payload|
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"delivery_info: #{delivery_info}\nproperties: #{properties}\npayload: #{payload}")
      begin
        # We know our own messages, so just skip them
        if properties[:app_id] == 'tng-gtk-sp'
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"leaving, we know our own messages, so just skip them...")
        else
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"properties[:app_id]: #{properties[:app_id]}")
      
          # We're interested in app_id == 'son-plugin.slm'
          parsed_payload = YAML.load(payload)
          LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"parsed_payload: #{parsed_payload}")
          status = parsed_payload['status']
          if status
            LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"status: #{status}")
            begin
              request = Request.find(properties[:correlation_id])
            ensure
              ActiveRecord::Base.clear_active_connections!
            end
            
            unless request
              LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"request #{properties[:correlation_id]} not found")
            else
              LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"status #{request['status']} updated to #{status}")
              request['status']=status
              if parsed_payload['error']
                request['error'] = parsed_payload['error']
              else
                request['instance_uuid'] = parsed_payload['nsr']['id'] if (parsed_payload.key?('nsr') && !parsed_payload['nsr'].empty? && parsed_payload['nsr']['id'])
                request['scaling_type'] = parsed_payload['scaling_type'] if parsed_payload.key?('scaling_type')
                request['duration'] = parsed_payload['duration'] if parsed_payload.key?('duration')
                request['function_uuids'] = parsed_payload['vnfrs'] if parsed_payload.key?('vnfrs')
              end
              request.save
              LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"leaving with request #{request.inspect}")
              notify_user(request.as_json) unless request['callback'].empty?
            end
          end
        end
      rescue Exception => e
        LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"#{e.message} (#{e.class}):#{e.backtrace.split('\n\t')}")
      end
    end
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



