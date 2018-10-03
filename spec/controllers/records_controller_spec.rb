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
require 'records_controller'
require 'fetch_service_records_service'

RSpec.describe RecordsController, type: :controller do
  def app() described_class end

  context 'services' do
    let(:service_uuid_1) {SecureRandom.uuid}
    let(:service_record_1) {{uuid: service_uuid_1}}
    let(:service_uuid_2) {SecureRandom.uuid}
    context 'with UUID given' do
      let(:service_uuid_2) {SecureRandom.uuid}
      it 'returns the existing service' do
        allow(FetchServiceRecordsService).to receive(:call).with(uuid: service_uuid_1).and_return('whatever')
        get '/services/'+service_uuid_1
        expect(last_response).to be_ok
        expect(last_response.body).to include('whatever')
      end
      it 'rejects non-existing function' do
        allow(FetchServiceRecordsService).to receive(:call).with(uuid: service_uuid_2).and_return({})
        get '/services/'+service_uuid_2
        expect(last_response).to be_not_found
      end
    end
    context 'without UUID given' do
      let(:service_record_2) {{uuid: service_uuid_2}}
      let(:service_records) {[ service_record_1, service_record_2]}
      it 'adding default parameters for page size and number' do
        allow(FetchServiceRecordsService).to receive(:call).with({}).and_return(service_records)
        get '/services/'
        expect(last_response).to be_ok
        expect(last_response.body).to eq(service_records.to_json)
      end

      it 'returning Ok (200) and an empty array when no service is found' do
        allow(FetchServiceRecordsService).to receive(:call).with({}).and_return([])
        get '/services/'
        expect(last_response).to be_ok
        expect(last_response.body).to eq([].to_json)
      end
    end
  end
  context 'functions' do
    let(:function_uuid_1) {SecureRandom.uuid}
    let(:function_record_1) {{uuid: function_uuid_1}}
    let(:function_uuid_2) {SecureRandom.uuid}
    context 'with UUID given' do
      let(:function_uuid_2) {SecureRandom.uuid}
      it 'returns the existing function' do
        allow(FetchFunctionRecordsService).to receive(:call).with(uuid: function_uuid_1).and_return('whatever')
        get '/functions/'+function_uuid_1
        expect(last_response).to be_ok
        expect(last_response.body).to include('whatever')
      end
      it 'rejects non-existing function' do
        allow(FetchFunctionRecordsService).to receive(:call).with(uuid: function_uuid_2).and_return({})
        get '/functions/'+function_uuid_2
        expect(last_response).to be_not_found
      end
    end
    context 'without UUID given' do
      let(:function_record_2) {{uuid: function_uuid_2}}
      let(:function_records) {[ function_record_1, function_record_2]}
      it 'adding default parameters for page size and number' do
        allow(FetchFunctionRecordsService).to receive(:call).with({}).and_return(function_records)
        get '/functions/'
        expect(last_response).to be_ok
        expect(last_response.body).to eq(function_records.to_json)
      end

      it 'returning Ok (200) and an empty array when no function is found' do
        allow(FetchFunctionRecordsService).to receive(:call).with({}).and_return([])
        get '/functions/'
        expect(last_response).to be_ok
        expect(last_response.body).to eq([].to_json)
      end
    end
  end
end