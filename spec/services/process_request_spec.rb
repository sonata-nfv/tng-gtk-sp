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
require_relative '../../services/process_create_slice_instance_request'
require_relative '../../services/fetch_nsd_service'

RSpec.describe ProcessRequestService do
  let(:uuid) {SecureRandom.uuid}
  let(:network_function_trio) {{ vnf_name: 'myvnf', vnf_vendor: 'eu.5gtango', vnf_version: '0.1'}}
  let(:network_functions) {[{ vnf_id: 'my_vnf'}.merge(network_function_trio)]}
  let(:service) {{
    uuid: uuid, 
    nsd: { vendor: 'eu.5gtango', name: 'my_service', version: '0.1', network_functions: network_functions},
    username: nil
  }}
  describe '.call' do
    let(:uuid_2) {SecureRandom.uuid}
    let(:customer_uuid) {SecureRandom.uuid}
    let(:sla_id) {SecureRandom.uuid}
    let(:service_instantiation_request) {{
      service_uuid: uuid, egresses:[], ingresses: [], blacklist: [], request_type: "CREATE_SERVICE", customer_uuid: customer_uuid, 
      sla_id: sla_id, callback: ''
    }}
    let(:service) {{uuid: uuid, nsd: { vendor: 'eu.5gtango', name: 'my_service', version: '0.1', network_functions: network_functions}, username: nil}}
    let(:saved_service_instantiation_request) {
      service_instantiation_request.merge!({
        id: "be9ff802-da73-4927-8433-11649b726d00", created_at: "2018-06-07 16:24:15", updated_at: "2018-06-07 16:24:15", 
        status: "NEW", instance_uuid: nil
      })
    }
    let(:function_trio) {{ 
      vendor: network_function_trio[:vnf_vendor],
      name: network_function_trio[:vnf_name],
      version: network_function_trio[:vnf_version]
    }}
    let(:function) {{uuid: SecureRandom.uuid, vnfd: function_trio}}
    let(:full_functions) {[function]}
    let(:message) {{
      'NSD'=> { 
        'vendor'=> service[:nsd][:vendor], 'name'=> service[:nsd][:name], 'version'=> service[:nsd][:version], 
        'network_functions'=>[{
          'vnf_id'=>service[:nsd][:network_functions][0][:vnf_id],
          'vnf_name'=>service[:nsd][:network_functions][0][:vnf_name],
          'vnf_vendor'=>service[:nsd][:network_functions][0][:vnf_vendor],
          'vnf_version'=>service[:nsd][:network_functions][0][:vnf_version]
        }],
        'uuid'=> service[:uuid]
      },
      'VNFD0'=> { 
        'vendor'=> full_functions[0][:vnfd][:vendor], 'name'=> full_functions[0][:vnfd][:name], 
        'version'=> full_functions[0][:vnfd][:version], 'uuid'=> full_functions[0][:uuid]
      },
      'egresses'=> [],
      'ingresses'=> [],
      'blacklist'=> [],
      'user_data'=> {
        'customer'=>{
          'uuid'=>customer_uuid, 'email'=>"sonata.admin@email.com", 'phone'=>nil, 
          'keys'=>{'public'=>nil, 'private'=>nil}, 'sla_id'=>sla_id
        }, 
        'developer'=>{'username'=>nil, 'email'=>nil, 'phone'=>nil}
      }
    }.to_yaml.to_s}
    let(:user_data) {{
      customer: {
        uuid: customer_uuid, email: 'sonata.admin@email.com', phone: nil, 
        keys: {public: nil, private: nil}, sla_id: sla_id
      }, 
      developer: {username: nil, email: nil, phone: nil}
    }}
    it 'returns {} when no request is found' do
      allow(FetchNSDService).to receive(:call).with(uuid: uuid_2).and_return({})
      expect(described_class.call({service_uuid: uuid_2})).to be_empty
    end
#    it 'returns the stored request' do
#      allow(FetchNSDService).to receive(:call).with(uuid: uuid).and_return(service)
#      allow(FetchVNFDsService).to receive(:call).with(function_trio).and_return([function])
#      allow(Request).to receive(:create).and_return(saved_service_instantiation_request) # .with(service_instantiation_request)
#      allow(FetchUserDataService).to receive(:call).and_return(user_data) #.with(customer_uuid, service[:username], sla_id)
#      allow(MessagePublishingService).to receive(:call).
#        with(message, :create_service, saved_service_instantiation_request[:id]).
#        and_return(message)
#      result = described_class.call({service_uuid: uuid})
#      STDERR.puts ">>>>>>>>>>> request = #{result}"
#     expect(result).to eq(saved_service_instantiation_request)
#    end
  end
=begin
  describe '.enrich_one existing' do
    let(:instance_uuid) {SecureRandom.uuid}
    
    context 'service instantiation request' do
      let(:instantiation_request) {{service_uuid: uuid, instance_uuid: '', request_type: "CREATE_SERVICE"}}
      let(:enriched) {{
        instance_uuid: '',
        request_type: "CREATE_SERVICE", service: {
          uuid: service[:uuid], vendor: service[:nsd][:vendor], name: service[:nsd][:name], version: service[:nsd][:version]
      }}}
      it 'is enriched with service vendor, name and version' do
        allow(FetchNSDService).to receive(:call).with({uuid: uuid}).and_return(service)
        allow(described_class).to receive(:get_service_uuid).with(instantiation_request).and_return(instantiation_request[:uuid])
        result = described_class.enrich_one(instantiation_request)
        STDERR.puts "result=#{result}"
        expect(result).to eq(enriched)
      end
    end
    context 'service instance termination request' do
      let(:termination_request) {{instance_uuid: instance_uuid, request_type: "TERMINATE_SERVICE"}}
      let(:enriched) {{
        instance_uuid: instance_uuid,
        request_type: "TERMINATE_SERVICE", service: {
          uuid: service[:uuid], vendor: service[:nsd][:vendor], name: service[:nsd][:name], version: service[:nsd][:version]
      }}}
      it 'is enriched with service vendor, name and version' do
        allow(FetchNSDService).to receive(:call).with({uuid: uuid}).and_return(service)
        allow(described_class).to receive(:get_service_uuid).with(termination_request).and_return(service[:uuid])
        result = described_class.enrich_one(termination_request)
        STDERR.puts "result=#{result}"
        expect(result).to eq(enriched)
      end
    end
  end
=end
end