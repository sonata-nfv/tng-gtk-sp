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
require 'uri'
require 'cache_service'

RSpec.describe CacheService do
  let(:uuid) {SecureRandom.uuid}
  context 'using Redis' do
    it 'it should be a RedisCache' do
      expect(described_class.strategy.to_s).to eq(CacheService::RedisCache.to_s)
    end
    context 'on a single request (using UUID)' do
      let(:data) {{uuid: uuid, other: {a:1, b:[2,3]}}}
      it 'should return what was stored' do
        described_class.set(data[:uuid], data.to_json)
        stored_data = JSON.parse(described_class.get(data[:uuid]), symbolize_names: :true)
        expect(stored_data).to eq(data)
      end
    end
    context 'on a multiple request (not using UUID)' do
      let(:uuid_2) {SecureRandom.uuid}
      let(:data) {[{uuid: uuid, other: {a:1, b:[2,3]}}, {uuid: uuid_2, other: {a:2, b:[4,5]}}]}
    end
  end
  context 'using memory' do
    #it 'it should be a MemoryCache' do
    #  expect(described_class.strategy.to_s).to eq(CacheService::MemoryCache.to_s)
    #end
    context 'on a single request (using UUID)' do
    end
    context 'on a multiple request (not using UUID)' do
    end
  end
end
