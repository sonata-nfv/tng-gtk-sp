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
require 'requests_controller'

RSpec.describe RequestsController, type: :controller do
  def app() described_class end
  let(:uuid_1) {SecureRandom.uuid}
  let(:requestid_1) {SecureRandom.uuid}
  let(:requestid_2) {SecureRandom.uuid}
  let(:instance_uuid_1) {SecureRandom.uuid}

  describe 'accepts service instantiation requests' 
=begin
  describe 'accepts service instance creation queries' do
    let(:request_1) {{ id: requestid_1, service_uuid: uuid_1, request_type:"CREATE_SERVICE"}}
    let(:service){{uuid: uuid_1, vendor: 'vendor', name: 'name', version: 'version'}}
    let(:enriched_request_1) {{ id: requestid_1, service: service, request_type:"CREATE_SERVICE"}}
    let(:record_1) { {descriptor_reference: uuid_1}}
  
    context 'with UUID given' do
      it 'and returns the existing request' do
        allow(Request).to receive(:find).with(request_1[:id]).and_return(request_1)
        allow(ProcessRequestService).to receive(:enrich_one).with(request_1).and_return(enriched_request_1)
        allow(FetchNSDService).to receive(:call).with(uuid: request_1[:service_uuid]).and_return(service)
        get '/'+request_1[:id]
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
      let(:instance_uuid_2) {SecureRandom.uuid}
      let(:request_2) {{id: requestid_2, service_uuid:uuid_2, request_type:"CREATE_SERVICE"}}
      let(:requests) {[ request_1, request_2]}
      let(:enriched_request_2) {{ id: requestid_2, service: service, request_type:"CREATE_SERVICE"}}
      let(:enriched_requests) {[enriched_request_1, enriched_request_2]}
      let(:record_2) { {descriptor_reference: uuid_2}}
      it 'adding default parameters for page size and number' do
        allow(Request).to receive_message_chain(:where, :limit, :offset).and_return(requests)
        allow(ProcessRequestService).to receive(:enrich).with(requests).and_return(enriched_requests)
        allow(FetchServiceRecordsService).to receive(:call).twice.and_return(record_1, record_2)
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
=end
  describe 'accepts service instance termination queries' do
    let(:request_1) {{ id: requestid_1, instance_uuid: instance_uuid_1, request_type:"TERMINATE_SERVICE"}}
    let(:record_1) { {descriptor_reference: uuid_1}}
    let(:strategies) {{ 
      'CREATE_SERVICE': ProcessRequestService, 
      'TERMINATE_SERVICE': ProcessRequestService,
      'CREATE_SLICE': ProcessCreateSliceInstanceRequest,
      'TERMINATE_SLICE': ProcessTerminateSliceInstanceRequest,
      'SCALE_SERVICE': ProcessScaleServiceInstanceRequest
    }}
  
    context 'with UUID given' do
      it 'and returns the existing request' do
        allow(ProcessRequestBase).to receive(:find).with(request_1[:id], strategies).and_return(request_1)
        allow(FetchServiceRecordsService).to receive(:call).with(uuid: request_1[:instance_uuid]).and_return({})
        get '/'+request_1[:id]
        expect(last_response).to be_ok
        expect(last_response.body).to eq(request_1.to_json)
      end
      it 'and rejects non-existing request' do
        allow(ProcessRequestBase).to receive(:find).with(requestid_2, strategies).and_raise(ActiveRecord::RecordNotFound)
        get '/'+requestid_2
        expect(last_response).to be_not_found
      end
    end
    context 'without UUID given' do
      let(:uuid_2) {SecureRandom.uuid}
      let(:instance_uuid_2) {SecureRandom.uuid}
      let(:request_2) {{id: requestid_2, instance_uuid: instance_uuid_2, request_type:"TERMINATE_SERVICE"}}
      let(:requests) {[ request_1, request_2]}
      let(:record_2) { {descriptor_reference: uuid_2}}
#      it 'adding default parameters for page size and number' do
#        allow(Request).to receive_message_chain(:where, :limit, :offset, :order).and_return(requests)
#        allow(FetchServiceRecordsService).to receive(:call).twice.and_return(record_1, record_2)
#        get '/'
#        expect(last_response).to be_ok
#        expect(last_response.body).to eq(requests.to_json)
#      end
  
#      it 'returning Ok (200) and an empty array when no service is found' do
#        allow(Request).to receive_message_chain(:where, :limit, :offset).and_raise(ActiveRecord::RecordNotFound)
#        get '/'
#        expect(last_response).to be_ok
#        expect(last_response.body).to eq([].to_json)
#      end
    end
  end
  
  describe 'processes slice instantiation callback' do
=begin
    context 'with valid event data' do
      let(:valid_event_data) {{
        original_event_uuid: uuid_1,
        event: 'slice_changed',
        correlation_id: uuid_1
      }}
      let(:valid_result) {{
         id: uuid_1, #"06a0fdeb-a5b4-4f4e-a8db-def87abdc3fb",
         created_at: "2018-07-04 15:24:08 UTC",
         updated_at: "2018-07-06 14:01:07 UTC",
         service_uuid: "534c3ade-1681-4edc-92d1-cfe260827f29",
         status: "READY",
         request_type: "CREATE_SLICE",
         instance_uuid: nil,
         ingresses: [],
         egresses: [],
         callback: "",
         blacklist: [],
         customer_name: '',
         customer_email: '',
         sla_id: nil,
         name: nil,
         error: nil
      }}
      it 'returning 200 (OK)' do
        allow(ProcessCreateSliceInstanceRequest).to receive(:process_callback).with(valid_event_data).and_return(valid_result)
        post '/'+uuid_1+'/on-change', valid_event_data.to_json, {"Content-Type"=>"application/json"}
        expect(last_response).to be_created
        #expect(last_response.body).to eq(valid_result_with_location.to_json)
      end
    end
  
    context 'with invalid event data' do
      let(:invalid_event_data) {{ original_event_uuid: uuid_1}}
      let(:valid_result) {{error: 'error'}}
      it 'returning error' do
        allow(ProcessCreateSliceInstanceRequest).to receive(:process_callback).with(invalid_event_data).and_return({})
        post '/'+uuid_1+'/on-change', invalid_event_data.to_json, {"Content-Type"=>"application/json"}
        expect(last_response).not_to be_ok
        expect(last_response.body).to match(/error/)
      end
    end
=end
  end
  
  describe 'processes instantiation request' do
    let(:slice_instantiation) {{
      request_type: 'CREATE_SLICE',
      nstId: uuid_1,
      customer_name: '',
      customer_email: ''
    }}
    let(:slicer_request) {{
      request_type: "CREATE_SLICE",
      nstId: "de627e9d-7f04-4e6a-9c44-63c37a2f2e0f",
      callback: "http://tng-gtk-sp:5000/requests/c13e3197-5afb-4d4f-a04a-2e8d25094786/on-change"
    }}
    
    let(:slicer_response) {{
      created_at: "2018-07-16T14:03:02.204+00:00", updated_at: "2018-07-16T14:03:02.204+00:00",
      description: "NSI_descriptor",
      flavorId: "",
      instantiateTime: "2018-07-16T14:01:31.447547",
      name: "NSI_16072019_1600",
      netServInstance_Uuid: [
        {
          servId: "4c7d854f-a0a1-451a-b31d-8447b4fd4fbc",
          servInstanceId: "e1547f09-e954-4299-bd62-138045566872",
          servName: "ns-squid-haproxy",
          workingStatus: "READY"
        }
      ],
      nsiState: "INSTANTIATED",
      nstId: "26c540a8-1e70-4242-beef-5e77dfa05a41",
      nstName: "Example_NST",
      nstVersion: "1.0",
      sapInfo: "",
      scaleTime: "",
      terminateTime: "",
      updateTime: "",
      uuid: "a75d1555-cc2c-4b96-864f-fa1ffe5c909a",
      vendor: "eu.5gTango"
    }}
    let(:service_instantiation) {{
      service_uuid: uuid_1,
      request_type: 'CREATE_SERVICE',
      customer_name: '',
      customer_email: ''
    }}
    let(:headers) {{
      'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 
      'Content-Type'=>'application/json', 'Host'=>'example.com', 'User-Agent'=>'Ruby'
    }}
    let(:saved_service_instantiation_request) {{
       id: uuid_1, #"06a0fdeb-a5b4-4f4e-a8db-def87abdc3fb",
       created_at: "2018-07-04 15:24:08 UTC",
       updated_at: "2018-07-06 14:01:07 UTC",
       service_uuid: service_instantiation[:service_uuid],
       status: "READY",
       request_type: "CREATE_SLICE",
       instance_uuid: nil,
       ingresses: [],
       egresses: [],
       callback: "",
       blacklist: [],
       customer_name: '',
       customer_email: '',
       sla_id: nil,
       name: nil,
       error: nil
    }}
    let(:enriched_saved_service_instantiation_request) {{
       id: uuid_1, #"06a0fdeb-a5b4-4f4e-a8db-def87abdc3fb",
       created_at: "2018-07-04 15:24:08 UTC",
       updated_at: "2018-07-06 14:01:07 UTC",
       service: {
         uuid: service_instantiation[:service_uuid],
         vendor: 'vendor',
         name: 'name',
         version: '0.0.1'
       },
       status: "READY",
       request_type: "CREATE_SLICE",
       instance_uuid: nil,
       ingresses: [],
       egresses: [],
       callback: "",
       blacklist: [],
       customer_name: '',
       customer_email: '',
       sla_id: nil,
       name: nil,
       error: nil
    }}
    
    before { header 'Content-Type', 'application/json'}
    it 'calling the ProcessCreateSliceInstanceRequest class to handle the slice creation request' do
      saved_request = double('Request', key?: false)
      allow(ProcessCreateSliceInstanceRequest).to receive(:call).with(slice_instantiation).and_return(saved_request)
      #allow(ProcessCreateSliceInstanceRequest).to receive(:create_slice).with(slice_instantiation).and_return(slicer_response)
      post '/', slice_instantiation.to_json
      stub_request(:post, "http://example.com/nsilcm/v1/nsi").with(body: slicer_request, headers: headers).to_return(status: 200, body: "", headers: {})
      expect(last_response).to be_created
    end
    it 'calling the ProcessRequestService class to handle the service creation request' do
      allow(ProcessRequestService).to receive(:call).with(service_instantiation).and_return(saved_service_instantiation_request)
      post '/', service_instantiation.to_json      
      expect(last_response).to be_created
      expect(last_response.body).to eq(saved_service_instantiation_request.to_json)
    end
  end
  describe 'raises an error' do
    let(:slice_instantiation) {{
      request_type: 'CREATE_SLICE',
      service_uuid: uuid_1,
      customer_name: '',
      customer_email: ''
    }}
    let(:wrong_request_type) {{
      request_type: 'WHATEVER_THIS_IS',
      service_uuid: uuid_1
    }}
    before { header 'Content-Type', 'application/json'}
    context '404 (not found)' do
      it 'when it is an unknown request type' do
        saved_request = double('Request')
        allow(ProcessRequestService).to receive(:call).with(wrong_request_type).and_raise(ArgumentError)
        post '/', wrong_request_type.to_json
        expect(last_response).to be_not_found
      end
      it 'when saving returns an error' do
        saved_request = double('Request')
        allow(ProcessCreateSliceInstanceRequest).to receive(:call).with(slice_instantiation).and_return({error: 'any error'})
        post '/', slice_instantiation.to_json
        expect(last_response).to be_bad_request # be_not_found
      end
    end
    context '400 (bad request)' do
      it 'when JSON params are wrong' do
        post '/', 'this is not JSON' # JSON::ParserError
        expect(last_response).to be_bad_request
      end
      it 'when params are empty' do
        post '/', ''
        expect(last_response).to be_bad_request
      end
      it 'when saving the request fails' do
        allow(ProcessCreateSliceInstanceRequest).to receive(:call).with(slice_instantiation).and_return(nil)
        post '/', slice_instantiation.to_json
        expect(last_response).to be_bad_request
      end
    end
    it 'when the request has a wrong content-type' do
      header 'Content-Type', 'whatever'
      post '/', slice_instantiation.to_json
      expect(last_response).to be_unsupported_media_type
    end
  end
end