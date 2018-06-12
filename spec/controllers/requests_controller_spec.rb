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

RSpec.describe RequestsController, type: :controller do
  include Rack::Test::Methods
  def app() RequestsController end
  let(:uuid_1) {SecureRandom.uuid}
  let(:requestid_1) {SecureRandom.uuid}
  let(:requestid_2) {SecureRandom.uuid}

  describe 'Accepts service instantiation requests' 
  describe 'Accepts service intance queries' do
    let(:service_1_metadata) {{uuid: uuid_1, nsd: {vendor: '5gtango', name: 'whatever', version: '0.0.1'}}}
    let(:service_2_metadata) {{uuid: uuid_2, nsd: {vendor: '5gtango', name: 'whatever', version: '0.0.2'}}}
    let(:request_1) {{
      id: requestid_1, created_at:"2018-06-07T16:28:39.571Z",updated_at:"2018-06-07T16:28:39.571Z",
      uuid:uuid_1,status:"NEW",request_type:"CREATE_SERVICE",instance_uuid: '',ingresses:[],egresses:[],began_at:"2018-06-07T16:28:39.557Z",
      callback:'',blacklist:[],customer_uuid:'',sla_uuid:''
    }}
    let(:services_metadata) {[service_1_metadata, service_2_metadata]}
  
    context 'with UUID given' do
      it 'and returns the existing request' do
        allow(Request).to receive(:find).with(requestid_1).and_return(request_1)
        get '/'+requestid_1
        expect(last_response).to be_ok
        expect(last_response.body).to eq(request_1.to_json)
      end
      it 'and rejects non-existing request' do
        allow(Request).to receive(:find).with(requestid_2).and_raise(ActiveRecord::RecordNotFound)
        get '/'+requestid_2
        expect(last_response).to be_not_found
      end
    end
    context 'without UUID given' do
      let(:uuid_2) {SecureRandom.uuid}
      let(:request_2) {{
        id: requestid_2, created_at:"2018-06-07T16:28:39.571Z",updated_at:"2018-06-07T16:28:39.571Z",
        uuid:uuid_2,status:"NEW",request_type:"CREATE_SERVICE",instance_uuid: '',ingresses:[],egresses:[],began_at:"2018-06-07T16:28:39.557Z",
        callback:'',blacklist:[],customer_uuid:'',sla_uuid:''
      }}
      let(:requests) {[ request_1, request_2]}
      it 'adding default parameters for page size and number' do
        allow(Request).to receive_message_chain(:where, :limit, :offset).and_return(requests)
        get '/'
        expect(last_response).to be_ok
        expect(last_response.body).to eq(requests.to_json)
      end
  
      it 'returning Ok (200) and an empty array when no service is found' do
        allow(Request).to receive_message_chain(:where, :limit, :offset).and_raise(ActiveRecord::RecordNotFound)
        get '/'
        expect(last_response).to be_ok
        expect(last_response.body).to eq([].to_json)
      end
    end
  end
end