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
require_relative '../../../spec_helper'
require_relative '../../../../services/request_strategies/slices/terminate_instance'
require 'request'
require_relative '../../../../services/process_request_service'

RSpec.describe RequestStrategies::Slices::TerminateInstance do
  let(:instance_uuid)  {SecureRandom.uuid}
  let(:request_uuid)   {SecureRandom.uuid}
  let(:callback)       {'http://example.com/user-callback'}
  let(:request_params) {{
    instance_uuid: instance_uuid,
     request_type: 'TERMINATE_SLICE',
         callback: callback
  }}
  let(:terminate_url) {"http://pre-int-sp-ath.5gtango.eu:5998/api/nsilcm/v1/nsi/#{instance_uuid}/terminate"}
  let(:callback_url)  {"http://tng-gtk-sp:5000/requests/#{request_uuid}/on-change"}
  let(:terminate_request_body) {{terminateTime:0, callback: callback_url}.to_json}
  describe '.call' do
    let(:request) {double 'Request', id: request_uuid, callback: ''}
    context 'when the requests is well built,' do    
      let(:ok_slm_body) {{status:'TERMINATING'}}
      let(:not_ok_slm_body) {{status:'ERROR', error: 'An error'}}
      it 'and the Slice Manager accepts it, it is saved with status \'TERMINATING\'' do
        allow(Request).to receive(:create).with(request_params).and_return(request)
        stub_request(:post, terminate_url).with(body: terminate_request_body).to_return(status: 200, body: ok_slm_body.to_json, headers: {})
        allow(request).to receive(:update).with({status: ok_slm_body[:status]})
        allow(request).to receive(:reload)
#        described_class.call(request_params)
      end
      it 'and the Slice Manager rejects it, it is saved with an error' do
        allow(Request).to receive(:create).with(request_params).and_return(request)
        stub_request(:post, terminate_url).with(body: terminate_request_body).to_return(status: 200, body: not_ok_slm_body.to_json, headers: {})
        expect(request).to receive(:update).with({status: not_ok_slm_body[:status], error: not_ok_slm_body[:error]})
        allow(request).to receive(:reload)
#        described_class.call(request_params)
      end
    end
    context 'when the requests is not well built, ' do
      it 'it is not saved' do
        allow(Request).to receive(:create).with(request_params).and_return(nil)
        described_class.call(request_params)
      end
    end
  end
  describe '.process_callback' do
    context 'when all is ok' do
      let(:event_data) {{
        original_event_uuid: request_uuid,
        nsiState: 'READY'
      }}
      let(:request) {instance_double 'Request'}
      let(:instance) {described_class.process_callback(event_data)}
      it 'processes the callback of the Slice Manager when the slice is ready' do
        #allow(Request).to receive(:find).with(request_uuid).and_return(request)
        #allow(described_class).to receive(:new).and_return(instance)
        #expect(instance).to have_received(:save_result)
      end
      it 'notifies user when a callback is present' do
        #allow(instance).to receive_messages(save_result: request, notify_user: request)
      end
    end
  end
end