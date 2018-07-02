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
#    terminate_service: 'service.instance.terminate',
    create_vim_computation: 'infrastructure.management.compute.add'
  }

  def self.call(message, queue_symbol, correlation_id)
    msg=self.name+'#'+__method__.to_s
    STDERR.puts "#{msg}: message=#{message}, queue_symbol=#{queue_symbol}, correlation_id=#{correlation_id}"
    raise ArgumentError.new('No MQServer URL has been defined') if MQSERVER_URL == ''
    raise ArgumentError.new("Queue must be one of :#{@@queues.keys.join(', :')}") unless @@queues.keys.include? queue_symbol
    raise ArgumentError.new('No correlation has been given') if correlation_id == ''

    channel = Bunny.new(MQSERVER_URL, automatically_recover: false).start.create_channel
    topic = channel.topic("son-kernel", auto_delete: false)
    queue = channel.queue(@@queues[queue_symbol], auto_delete: true).bind(topic, routing_key: @@queues[queue_symbol])
    self.send(:"consume_#{queue_symbol.to_s}", queue: queue)
    published = topic.publish( message, content_type:'text/yaml', routing_key: queue.name, correlation_id: correlation_id, reply_to: queue.name, app_id: 'son-gkeeper')
    STDERR.puts "#{msg}: published=#{published}"
    published
  end  
  
  private
  def self.consume_create_service(queue:)
    msg=self.name+'#'+__method__.to_s
    STDERR.puts "#{msg}: entered"
    queue.subscribe do |delivery_info, properties, payload|
      STDERR.puts "#{msg}: delivery_info: #{delivery_info}"
      STDERR.puts "#{msg}: properties: #{properties}"
      STDERR.puts "#{msg}: payload: #{payload}"
      begin

        # We know our own messages, so just skip them
        return if properties[:app_id] == 'son-gkeeper'
        
        # We're interested in app_id == 'son-plugin.slm'
        parsed_payload = YAML.load(payload)
        STDERR.puts "#{msg}: parsed_payload: #{parsed_payload}"
        status = parsed_payload['status']
        unless status
          STDERR.puts "#{msg}: status not present"
          return
        end
        STDERR.puts "#{msg}: status: #{status}"
        request = Request.find_by(id: properties[:correlation_id])
        unless request
          STDERR.puts "#{msg}: request #{properties[:correlation_id]} not found"
          return
        end
        STDERR.puts "#{msg}: request['status'] #{request['status']} turned into #{status}"
        request['status']=status
        if request['error']
          STDERR.puts "#{msg}: error was #{request['error']}"
          return
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
        return
      rescue Exception => e
        STDERR.puts "#{msg}: #{e.message}"
        STDERR.puts "#{msg}: #{e.backtrace.split('\n\t')}"
        return
      end
      STDERR.puts "#{msg}: leaving"
    end
  end
end



