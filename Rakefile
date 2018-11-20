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
require 'rspec/core/rake_task'
require 'ci/reporter/rake/rspec'
require 'sinatra/activerecord/rake'
require 'tng/gtk/utils/application_controller'
%w{ controllers models services }.each do |dir|
  path = File.expand_path(File.join(File.dirname(__FILE__), '../', dir))
  $LOAD_PATH << path
end
require_relative './controllers/requests_controller'

task default: ['ci:all']

desc 'Run Unit Tests'
RSpec::Core::RakeTask.new :specs do |task|
  task.pattern = Dir['spec/**/*_spec.rb']
end

# use like in
#   rake ci:all
desc 'Runs all test tasks'
task 'ci:all' => ['ci:setup:rspec', 'specs']

namespace :db do
  task :load_config do
    require './controllers/requests_controller'
  end
end

# from https://opensoul.org/2012/05/30/releasing-multiple-gems-from-one-repository/
#desc 'Build gem into the pkg directory'
#task :build do
#  FileUtils.rm_rf('pkg')
#  Dir['*.gemspec'].each do |gemspec|
#    system "gem build #{gemspec}"
#  end
#  FileUtils.mkdir_p('pkg')
#  FileUtils.mv(Dir['*.gem'], 'pkg')
#end

#desc 'Tags version, pushes to remote, and pushes gem'
#task :release => :build do
#  sh 'git', 'tag', '-m', changelog, "v#{Qu::VERSION}"
#  sh "git push origin master"
#  sh "git push origin v#{Qu::VERSION}"
#  sh "ls pkg/*.gem | xargs -n 1 gem push"
#end