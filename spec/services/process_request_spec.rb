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
# frozen_string_literal: true
# encoding: utf-8
require_relative '../spec_helper'

RSpec.describe ProcessRequestService do
  describe '.call' do
    let(:uuid) {SecureRandom.uuid}
    let(:customer_uuid) {SecureRandom.uuid}
    let(:sla_id) {SecureRandom.uuid}
    let(:service_instantiation_request) {{
      uuid: uuid, egresses:[], ingresses: [], blacklist: [], customer_uuid: customer_uuid, sla_id: sla_id
    }}
    let(:functions) {[{ 'vnf_id'=> 'my_vnf', 'vnf_name'=> 'myvnf', 'vnf_vendor'=>'eu.5gtango', 'vnf_version'=> '0.1'}]}
    let(:service) {{uuid: uuid, nsd: { vendor: 'eu.5gtango', name: 'my_service', version: '0.1', network_functions: functions}, username: nil}}
    let(:saved_service_instantiation_request) {{
      id: "be9ff802-da73-4927-8433-11649b726d00", created_at: "2018-06-07 16:24:15", updated_at: "2018-06-07 16:24:15", 
      uuid: uuid, status: "NEW", request_type: "CREATE_SERVICE", 
      instance_uuid: nil, ingresses: [], egresses: [], began_at: "2018-06-07 16:24:15", 
      callback: nil, blacklist: [], customer_uuid: customer_uuid, sla_uuid: sla_id
    }}
    let(:function) {{
      uuid: SecureRandom.uuid, vnfd: { vendor: functions[0]['vnf_vendor'], name: functions[0]['vnf_name'], version: functions[0]['vnf_version']}
    }}
    let(:full_functions) {[function]}
    let(:message) {{
      'NSD'=> { 
        'vendor'=> service[:nsd][:vendor], 'name'=> service[:nsd][:name], 'version'=> service[:nsd][:version], 
        'network_functions'=>functions,
        'uuid'=> service[:uuid]
      },
      'VNFD0'=> { 
        'vendor'=> full_functions[0][:vnfd][:vendor], 'name'=> full_functions[0][:vnfd][:name], 
        'version'=> full_functions[0][:vnfd][:version], 'uuid'=> full_functions[0][:uuid]
      },
      'egresses'=> [],
      'ingresses'=> [],
      'user_data'=> {
        'customer'=>{
          'uuid'=>customer_uuid, 'email'=>"sonata.admin@email.com", 'phone'=>nil, 
          'keys'=>{'public'=>nil, 'private'=>nil}, 'sla_uuid'=>sla_id
        }, 
        'developer'=>{'username'=>nil, 'email'=>nil, 'phone'=>nil}
      }
    }.to_yaml}
    let(:user_data) {{
      customer: {
        uuid: customer_uuid, email: 'sonata.admin@email.com', phone: nil, 
        keys: {public: nil, private: nil}, sla_uuid: sla_id
      }, 
      developer: {username: nil, email: nil, phone: nil}
    }}
    it 'returns the stored request' do
      allow(FetchNSDService).to receive(:call).with(uuid: service_instantiation_request[:uuid]).and_return(service)
      allow(FetchVNFDsService).to receive(:call).with(service[:nsd][:network_functions][0]).and_return(function)
      allow(Request).to receive(:create).with(service_instantiation_request).and_return(saved_service_instantiation_request)
      allow(FetchUserDataService).to receive(:call).with(customer_uuid, service[:username], sla_id).and_return(user_data)
      allow(MessagePublishingService).to receive(:call).with(message, :create_service, saved_service_instantiation_request[:id]).and_return(message)
      expect(described_class.call(service_instantiation_request)).to eq(saved_service_instantiation_request)
    end
  end
end