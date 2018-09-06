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

class MessagePublishingService  
  ERROR_VNFS_ARE_MANDATORY='VNFs parameter is mandatory'
  ERROR_VNF_CATALOGUE_URL_NOT_FOUND='VNF Catalogue URL not found in the ENV.'
  MQSERVER_URL = ENV.fetch('MQSERVER_URL', '')
  @@queues = {
    create_service: 'service.instances.create',
#    update_service: 'service.instances.update',
    terminate_service: 'service.instance.terminate' #,
#    create_vim_computation: 'infrastructure.management.compute.add'
  }

  def self.call(message, queue_symbol, correlation_id)
    msg=self.name+'#'+__method__.to_s
    STDERR.puts "#{msg}: message=#{message}, queue_symbol=#{queue_symbol}, correlation_id=#{correlation_id}"
    raise ArgumentError.new('No MQServer URL has been defined') if MQSERVER_URL == ''
    raise ArgumentError.new("Queue must be one of :#{@@queues.keys.join(', :')}") unless @@queues.keys.include? queue_symbol
    raise ArgumentError.new('No correlation has been given') if correlation_id == ''

=begin
    routing key == topic == service.instances.create
    you queue name is independent and can have any name and then binded to the exchange "son-kernel" and routing key "service.instances.create"
    what @tsoenen suggested is that your queue name should have different name than the routing key == topic
=end
    begin
      channel = Bunny.new(MQSERVER_URL, automatically_recover: false).start.create_channel
    rescue Bunny::TCPConnectionFailed => e
      STDERR.puts "#{msg}: Connection to #{MQSERVER_URL} failed"
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
    STDERR.puts "#{msg}: published=#{published.inspect}"
    published
  end  
  
  private
  def self.service_instances_create(queue:)
    msg=self.name+'#'+__method__.to_s
    STDERR.puts "#{msg}: entered"
    queue.subscribe do |delivery_info, properties, payload|
      STDERR.puts "#{msg}: delivery_info: #{delivery_info}"
      STDERR.puts "#{msg}: properties: #{properties}"
      STDERR.puts "#{msg}: payload: #{payload}"
      begin

        # We know our own messages, so just skip them
        if properties[:app_id] == 'tng-gtk-sp'
          STDERR.puts "#{msg}: leaving, we know our own messages, so just skip them..."
        else
          STDERR.puts "#{msg}: properties[:app_id]: #{properties[:app_id]}"
      
          # We're interested in app_id == 'son-plugin.slm'
          parsed_payload = YAML.load(payload)
          STDERR.puts "#{msg}: parsed_payload: #{parsed_payload}"
          status = parsed_payload['status']
          if status
            STDERR.puts "#{msg}: status: #{status}"
            request = Request.find(properties[:correlation_id])
            unless request
              STDERR.puts "#{msg}: request #{properties[:correlation_id]} not found"
              return
            end
            STDERR.puts "#{msg}: status #{request['status']} updated to #{status}"
            request['status']=status
            if parsed_payload['error']
              request['error'] = parsed_payload['error']
              request.save
              STDERR.puts "#{msg}: leaving with error #{request['error']}"
            else
              unless parsed_payload.key?('nsr')
                STDERR.puts "#{msg}: no 'nsr' key in #{parsed_payload}"
              else
                # if this is a final answer, there'll be an NSR
                service_instance = parsed_payload['nsr']
                if service_instance.key?('id')
                  STDERR.puts "#{msg}: request['instance_uuid']='#{service_instance['id']}'"
                  request['instance_uuid'] = service_instance['id']
                else
                  STDERR.puts "#{msg}: no service instance uuid"
                end
              end
              request.save
              STDERR.puts "#{msg}: request #{request} saved"
            end
          end
        end
      rescue Exception => e
        STDERR.puts "#{msg}: #{e.message} (#{e.class})"
        STDERR.puts "#{msg}: #{e.backtrace.split('\n\t')}"
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
    msg=self.name+'#'+__method__.to_s
    STDERR.puts "#{msg}: entered"
    queue.subscribe do |delivery_info, properties, payload|
      STDERR.puts "#{msg}: delivery_info: #{delivery_info}"
      STDERR.puts "#{msg}: properties: #{properties}"
      STDERR.puts "#{msg}: payload: #{payload}"
      begin

        # We know our own messages, so just skip them
        # We know our own messages, so just skip them
        if properties[:app_id] == 'tng-gtk-sp'
          STDERR.puts "#{msg}: leaving, we know our own messages, so just skip them..."
        else
          STDERR.puts "#{msg}: properties[:app_id]: #{properties[:app_id]}"
      
          # We're interested in app_id == 'son-plugin.slm'
          parsed_payload = YAML.load(payload)
          STDERR.puts "#{msg}: parsed_payload: #{parsed_payload}"
          status = parsed_payload['status']
          if status
            STDERR.puts "#{msg}: status: #{status}"
            request = Request.find(properties[:correlation_id])
            if request
              STDERR.puts "#{msg}: request['status'] #{request['status']} turned into #{status}"
              request['status']=status
              if request['error']
                STDERR.puts "#{msg}: error was #{request['error']}"
              end
              # if this is a final answer, there'll be an NSR
              service_instance = parsed_payload['nsr']
              if service_instance && service_instance.key?('id')
                instance_uuid = parsed_payload['nsr']['id']
                STDERR.puts "#{msg}: request['instance_uuid'] #{request['instance_uuid']} turned into #{instance_uuid}"
                request['instance_uuid'] = instance_uuid
              end

              request.save
              STDERR.puts "#{msg}: request saved"
            else
              STDERR.puts "#{msg}: request #{properties[:correlation_id]} not found"
            end
          end
        end
      rescue Exception => e
        STDERR.puts "#{msg}: #{e.message} (#{e.class})"
        STDERR.puts "#{msg}: #{e.backtrace.split('\n\t')}"
      end
    end
  end
end



