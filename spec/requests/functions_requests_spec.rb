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

RSpec.describe FunctionsController, type: :controller do
  def app() described_class end
  let(:site)  {FetchVNFDsService.site}
  let(:uuid_1) {SecureRandom.uuid}
  let(:function_1_metadata) {{uuid: uuid_1, vnfd: {vendor: '5gtango', name: 'whatever', version: '0.0.1'}}}
  let(:uuid_2) {SecureRandom.uuid}
  let(:headers) do
    uri = URI(site)
    {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/json', 
      'Host'=>"#{uri.host}:#{uri.port}", 'User-Agent'=>'Ruby'}
  end

  context 'with UUID given' do
    it 'returns the existing function' do
      stub_request(:get, site+'/'+uuid_1).with(headers: headers).to_return(status: 200, body: function_1_metadata.to_json, headers: headers)
      get '/'+uuid_1
      expect(last_response).to be_ok
      expect(last_response.body).to eq(function_1_metadata.to_json)
    end
    it 'rejects non-existing function' do
      stub_request(:get, site+'/'+uuid_2).with(headers: headers).to_return(status: 404, body: '', headers: headers)
      get '/'+uuid_2
      STDERR.puts "last_response=#{last_response.inspect}"
      expect(last_response).to be_not_found
    end
  end
=begin
  context 'without UUID given' do
    let(:function_2_metadata) {{uuid: uuid_2, vnfd: {vendor: '5gtango', name: 'whatever', version: '0.0.1'}}}
    let(:functions) {[ function_1_metadata, function_2_metadata]}
    it 'adding default parameters for page size and number' do
      stub_request(:get, site+'?page_number='+default_page_number+'&page_size='+default_page_size).
        with(headers: headers).to_return(status: 200, body: services_metadata.to_json, headers: headers)
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to eq(functions.to_json)
    end

    it 'returning Ok (200) and an empty array when no service is found' do
      allow(FetchVNFDsService).to receive(:call).with({}).and_return([])
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to eq([].to_json)
    end
  end
=end
end