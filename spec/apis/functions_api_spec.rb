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

RSpec.describe 'Functions API', type: :api do
  def app() FunctionsController end
  let(:site)  {FetchVNFDsService.site}
  let(:uuid_1) {SecureRandom.uuid}
  let(:function_1_metadata) {{uuid: uuid_1, vnfd: {vendor: '5gtango', name: 'whatever', version: '0.0.1'}}}
  let(:uuid_2) {SecureRandom.uuid}

  context 'with UUID given' do
    #describe "API authentication" , :type => :api do
    #  let!(:user) { FactoryGirl.create(:user) }
    #  it "making a request without cookie token " do
    #    get "/api/v1/items/1",:formate =>:json
    #    last_response.status.should eql(401)
    #    error = {:error=>'You need to sign in or sign up before continuing.'}
    #    last_response.body.should  eql(error.to_json)
    #  end
    #end
=begin
    it 'returns the existing function' do
      stub_request(:get, site+'/'+uuid_1).to_return(status: 200, body: function_1_metadata.to_json, headers: {})
      get '/'+uuid_1
      expect(response).to have_http_status(:success)
      #expect(response).to be_success
      #json = JSON.parse(response.body)
      expect(response.body).to include(function_1_metadata.to_json)
    end
    it 'rejects non-existing function' do
      stub_request(:get, site+'/'+uuid_2).to_return(status: 404, body: '', headers: {})
      get '/'+uuid_2
      expect(esponse).to eq(404)
    end
=end
  end
end