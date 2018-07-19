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
source 'https://rubygems.org'
ruby '2.4.3'

gem 'rake', '12.3.0'
gem 'sinatra', '2.0.2', require: 'sinatra/base'
gem 'sinatra-contrib', '2.0.2', require: false
gem 'sinatra-logger', '0.3.2'
#gem 'sinatra-active-model-serializers', '0.1.0'
gem 'sinatra-cross_origin', '0.4.0'

gem 'pg', '0.21.0'
gem 'activerecord', '5.2'
gem 'sinatra-activerecord', '2.0.13'
gem 'bunny', '2.8.0'

gem 'puma', '3.11.0'
gem 'ci_reporter_rspec', '1.0.0'
gem 'rubocop', '0.52.0'
gem 'rubocop-checkstyle_formatter', '0.4.0', require: false

group :test do
  gem 'webmock', '3.1.1'
  gem 'rspec', '3.7.0'
  gem 'rack-test', '0.8.2'
#  gem 'rspec-its', '1.2.0'
#  gem 'bunny-mock', '1.7.0'
#  gem 'factory_bot', '4.8.2'
end
