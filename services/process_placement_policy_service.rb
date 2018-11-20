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
require 'tng/gtk/utils/fetch'
require 'tng/gtk/utils/logger'

class ProcessPlacementPolicyService < Tng::Gtk::Utils::Fetch
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  NO_POLICY_MNGR_URL_DEFINED_ERROR='The POLICY_MNGR_URL ENV variable needs to defined and pointing to the Policy Manager where to manage policies'
  POLICY_MNGR_URL = ENV.fetch('POLICY_MNGR_URL', '')
  if POLICY_MNGR_URL == ''
    LOGGER.error(component:LOGGED_COMPONENT, operation:'fetching POLICY_MNGR_URL ENV variable', message:NO_POLICY_MNGR_URL_DEFINED_ERROR)
    raise ArgumentError.new(NO_POLICY_MNGR_URL_DEFINED_ERROR) 
  end
  self.site=POLICY_MNGR_URL+'/placement'
  
  def self.add(params)
  end
end


