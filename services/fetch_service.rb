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
require 'json'
require_relative './cache_service'

class FetchService
  
  class << self
    attr_accessor :site
  end

  def site=(value) self.class.site = value end
  def site() self.class.site end
  
  def self.call(params)
    msg=self.name+'#'+__method__.to_s
    STDERR.puts "#{msg}: params=#{params} site=#{self.site}"
    original_params = params.dup
    begin
      if params.key?(:uuid)
        cached = CacheService.get("#{CACHE_PREFIX}:#{params[:uuid]}")
        STDERR.puts "#{msg}: cached=#{cached}"
        if cached
          json_cached=JSON.parse(cached, quirks_mode: true, symbolize_names: true)
          STDERR.puts "#{msg}: json_cached=#{json_cached}"
          return json_cached
        end
        uuid = params.delete :uuid
        uri = URI.parse("#{self.site}/#{uuid}")
        # mind that there cany be more params, so we might need to pass params as well
      else
        uri = URI.parse(self.site)
        uri.query = URI.encode_www_form(sanitize(params))
      end
      STDERR.puts "#{msg}: uri=#{uri}"
      request = Net::HTTP::Get.new(uri)
      request['content-type'] = 'application/json'
      response = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(request)}
      STDERR.puts "#{msg}: response=#{response.inspect}"
      case response
      when Net::HTTPSuccess
        body = response.read_body
        STDERR.puts "#{msg}: 200 (Ok) body=#{body}"
        result = JSON.parse(body, quirks_mode: true, symbolize_names: true)
        cache_result(result)
        return result
      when Net::HTTPNotFound
        STDERR.puts "#{msg}: 404 Not found body=#{body}"
        return {} unless uuid.nil?
        return []
      else
        return nil # ArgumentError.new("#{response.message}")
      end
    rescue Exception => e
      STDERR.puts "%s - %s: %s" % [Time.now.utc.to_s, msg, e.message]
    end
    nil
  end
  
  private
  def self.sanitize(params)
    params[:page_number] ||= ENV.fetch('DEFAULT_PAGE_NUMBER', 0)
    params[:page_size]   ||= ENV.fetch('DEFAULT_PAGE_SIZE', 100)
    params
  end
  
  def self.cache_result(result)
    msg=self.name+'#'+__method__.to_s
    STDERR.puts "#{msg} result=#{result})"
    if result.is_a?(Hash)      
      CacheService.set("#{CACHE_PREFIX}:#{result[:uuid]}", result.to_json) if result.key?(:uuid)
      return
    end
    result.each do |record|
      CacheService.set("#{CACHE_PREFIX}:#{record[:uuid]}", record.to_json) if record.key?(:uuid)
    end
  end
end
