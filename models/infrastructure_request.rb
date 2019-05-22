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
require 'json'
require 'sinatra/activerecord'
require 'tng/gtk/utils/logger'
require_relative '../services/messaging_service'

class InfrastructureRequest < ActiveRecord::Base
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  serialize :vim_list
  serialize :nep_list
  self.establish_connection(
    adapter:  "postgresql",
    host:     ENV.fetch('DATABASE_HOST','son-postgres'),
    port:     ENV.fetch('DATABASE_PORT', 5432),
    username: ENV.fetch('POSTGRES_USER', 'postgres'),
    password: ENV.fetch('POSTGRES_PASSWORD', 'sonatatest'),
    database: ENV.fetch('DATABASE_NAME', 'gatekeeper'),
    pool:     64,
    timeout:  10000,
    encoding: 'unicode'
  )
  STDERR.puts ">>> InfrastructureRequest is Connected to #{self.connection.current_database}"
  STDERR.puts ">>> InfrastructureRequest.configurations=:#{InfrastructureRequest.configurations}"
  STDERR.puts ">>> InfrastructureRequest.connection_pool.stat=#{InfrastructureRequest.connection_pool.stat}"
  def vim_from_json
    begin
      JSON.parse self[:vim_list]
    rescue
      []
    end
  end
  
  def save!
    msg='#'+__method__.to_s
    begin
      super
    rescue ActiveRecord::RecordNotSaved => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Record #{self.inspect} wasn't saved")
    rescue ActiveRecord::RecordInvalid  => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Record #{self.inspect} isn't valid")
    ensure
      self.connection_pool.flush!
      self.clear_active_connections!
    end
  end
end

class SliceVimResourcesRequest < InfrastructureRequest
  def as_json
    {
      created_at: self[:created_at],
      error: self[:error],
      id: self[:id],
      nep_list: self[:nep_list] ||= '[]',
      status: self[:status],
      updated_at: self[:updated_at],
      vim_list: self[:vim_list] ||= '[]'
    }
  end
end

class SliceNetworksCreationRequest < InfrastructureRequest
  validates :instance_uuid, presence: true
    
  def as_json
    {
      created_at: self[:created_at],
      error: self[:error],
      id: self[:id],
      instance_id: self[:instance_uuid],
      status: self[:status],
      updated_at: self[:updated_at],
      vim_list: vim_from_json
    }
  end
end

class SliceNetworksDeletionRequest < InfrastructureRequest
  validates :instance_uuid, presence: true
  
  def as_json
    {
      created_at: self[:created_at],
      error: self[:error],
      id: self[:id],
      instance_id: self[:instance_uuid],
      status: self[:status],
      updated_at: self[:updated_at],
      vim_list: vim_from_json
    }
  end
end