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
# encoding: utf-8
FROM ruby:2.4.3-slim-stretch
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential libcurl3 libcurl3-gnutls libcurl4-openssl-dev libpq-dev git && \
          apt-get clean && \
          apt-get autoremove && \
	  rm -rf /var/lib/apt/lists/*
RUN mkdir -p /app/lib/local-gems
WORKDIR /app
COPY Gemfile /app
RUN bundle install


FROM ruby:2.4.3-slim-stretch
COPY --from=0 /app/lib/local-gems /app/lib/local-gems
COPY --from=0 /usr/local/bundle /usr/local/bundle
RUN apt-get update && \
    apt-get install -y --no-install-recommends libcurl3 libcurl3-gnutls libcurl4-openssl-dev libpq-dev && \
          apt-get clean && \
          apt-get autoremove && \
	  rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . /app
EXPOSE 5000
ENV POSTGRES_DB gatekeeper
ENV POSTGRES_PASSWORD tango
ENV POSTGRES_USER tangodefault
ENV DATABASE_HOST son-postgres
ENV DATABASE_PORT 5432
#ENV DATABASE_URL=postgresql://tangodefault:tango@son-postgres:5432/gatekeeper
ENV MQSERVER_URL=amqp://guest:guest@son-broker:5672
ENV CATALOGUE_URL=http://tng-cat:4011/catalogues/api/v2
ENV REPOSITORY_URL=http://tng-rep:4012
ENV POLICY_MNGR_URL=http://tng-policy-mngr:8081/api/v1
ENV SLM_URL=http://tng-slice-mngr:5998/api
ENV SLICE_INSTANCE_CHANGE_CALLBACK_URL=http://tng-gtk-sp:5000/requests
#ENV SLICE_INSTANCE_CHANGE_CALLBACK_URL=http://tng-slice-mngr:5998/api/nsilcm/v1/nsi
ENV REDIS_URL=redis://son-redis:6379
ENV PORT=5000
ENV LOGLEVEL=debug
#CMD ["bundle", "exec", "rackup", "-p", "5000", "--host", "0.0.0.0"]
#CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
CMD ["bundle", "exec", "thin", "-p", "5000", "-D", "start"]

