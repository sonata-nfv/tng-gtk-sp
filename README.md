[![Build Status](https://jenkins.sonata-nfv.eu/buildStatus/icon?job=tng-gtk-sp/master)](https://jenkins.sonata-nfv.eu/job/tng-gtk-sp/master)
[![Join the chat at https://gitter.im/5gtango/tango-schema](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/5gtango/tango-schema)

<p align="center"><img src="https://github.com/sonata-nfv/tng-api-gtw/wiki/images/sonata-5gtango-logo-500px.png" /></p>

# Service Platform-specific Gatekeeper component
This is the 5GTANGO Gatekeeper Service Platform specific components repository, which implement the Gatekeeper features that are specific to the 5GTANGO Ssrvice Platform.

For details on the overall 5GTANGO architecture [please check here](https://5gtango.eu/project-outcomes/deliverables/2-uncategorised/31-d2-2-architecture-design.html). The Gatekeeper is the component highlighted in the following picture.

<p align="center"><img src="https://github.com/sonata-nfv/tng-api-gtw/wiki/images/GKs_place_in_5GTANGO_architecture.png" /></p>

You might also be interested in the following related repositories:

* [V&V and Service Platforms common component](https://github.com/sonata-nfv/tng-gtk-common);
* [V&V Platform specific component](https://github.com/sonata-nfv/tng-gtk-vnv).

## Installing / Getting started

This component is implemented in [ruby](https://www.ruby-lang.org/en/) (we're using version **2.4.3**). 

### Installing from code

To have it up and running from code, please do the following:

```shell
$ git clone https://github.com/sonata-nfv/tng-gtk-sp.git # Clone this repository
$ cd tng-gtk-sp # Go to the newly created folder
$ bundle install # Install dependencies
$ PORT=5000 bundle exec rackup # dev server at http://localhost:5000
```
**Note:** See the [Configuration](#configuration) section below for other environment variables that can be used.

Everything being fine, you'll have a server running on that session, on port `5000`. You can aesscc it by using `curl`, like in:

```shell
$ curl <host name>:5000/
```

### Installing from the Docker container
In case you prefer a `docker` based development, you can run the following commands (`bash` shell):

```shell
$ docker network create tango
$ docker run -d -p 27017:27017 --net=tango --name mongo mongo
$ docker run -d -p 5432:5432 --net=tango --name postgres postgres
$ docker run -d -p 5672:5672 --net=tango --name rabbitmq rabbitmq
$ docker run -d -p 4011:4011 --net=tango --name tng-cat sonatanfv/tng-cat:dev
$ docker run -d -p 4012:4012 --net=tango --name tng-rep sonatanfv/tng-rep:dev
$ docker run -d -p 5000:5000 --net=tango --name tng-gtk-sp \
  -e CATALOGUE_URL=http://tng-cat:4011/catalogues/api/v2 \
  -e REPOSITORY_URL=http://tng-cat:4012 \
  -e MQSERVER_URL=amqp://guest:guest@rabbitmq:5672 \
  -e POSTGRES_PASSWORD=tango \
  -e POSTGRES_USER=tangodefault \
  -e DATABASE_HOST=postgres \
  -e DATABASE_PORT=5432 \
  sonatanfv/tng-gtk-sp:dev
```

**Note:** user and password are mere indicative, please choose the apropriate ones for your deployment.

With these commands, you:

1. Create a `docker` network named `tango`;
1. Run the [MongoDB](https://www.mongodb.com/) container within the `tango` network;
1. Run the [PostgreSQL](https://www.postgresql.org/) container within the `tango` network;
1. Run the [RabbitMQ](https://www.rabbitmq.com/) container within the `tango` network;
1. Run the [Catalogue](https://github.com/sonata-nfv/tng-cat) container within the `tango` network;
1. Run the [Repository](https://github.com/sonata-nfv/tng-rep) container within the `tango` network;
1. Run the [SP-specific Gatekeeper](https://github.com/sonata-nfv/tng-gtk-sp) container within the `tango` network, with the needed environment variables set to the previously created containers.

## Developing
This section covers all the needs a developer has in order to be able to contribute to this project.

### Dependencies
We are using the following libraries (also referenced in the [`Gemfile`](https://github.com/sonata-nfv/tng-gtk-sp/Gemfile) file) for development:

* `activerecord` (`5.2`), the *Object-Relational Mapper (ORM)*;
* `bunny` (`2.8.0`), the adapter to the [RabbitMQ](https://www.rabbitmq.com/) message queue server;
* `pg` (`0.21.0`), the adapter to the [PostgreSQL](https://www.postgresql.org/) database;
* `puma` (`3.11.0`), an application server;
* `rack` (`2.0.4`), a web-server interfacing library, on top of which `sinatra` has been built;
* `rake`(`12.3.0`), a dependencies management tool for ruby, similar to *make*;
* `sinatra` (`2.0.2`), a web framework for implementing efficient ruby APIs;
* `sinatra-activerecord` (`2.0.13`), 
* `sinatra-contrib` (`2.0.2`), several add-ons to `sinatra`;
* `sinatra-cross_origin` (`0.4.0`), a *middleware* to `sinatra` that helps in managing the [`Cross Origin Resource Sharing (CORS)`](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) problem;
* `sinatra-logger` (`0.3.2`), a *logger* *middleware*;

The following *gems* (libraries) are used just for tests:
* `ci_reporter_rspec` (`1.0.0`), a library for helping in generating continuous integration (CI) test reports;
* `rack-test` (`0.8.2`), a helper testing framework for `rack`-based applications;
* `rspec` (`3.7.0`), a testing framework for ruby;
* `rubocop` (`0.52.0`), a library for white box tests; 
* `rubocop-checkstyle_formatter` (`0.4.0`), a helper library for `rubocop`;
* `webmock` (`3.1.1`), which alows *mocking* (i.e., faking) HTTP calls;

These libraries are installed/updated in the developer's machine when running the command (see above):

```shell
$ bundle install
```

### Prerequisites
We usually use [`rbenv`](https://github.com/rbenv/rbenv) as the ruby version manager, but others like [`rvm`](https://rvm.io/) may work as well.

### Setting up Dev
Developing this micro-service is straightforward with a low amount of necessary steps.

Routes within the micro-service are defined in the [`config.ru`](https://github.com/sonata-nfv/tng-gtk-sp/blob/master/config.ru) file, in the root directory. It has two sections:

* The `require` section, where all used libraries must be required (**Note:** `controllers` had to be required explicitly, while `services` do not, due to a bug we have found to happened in some of the environments);
* The `map` section, where this micro-service's routes are mapped to the controller responsible for it.

This new or updated route can then be mapped either into an existing controller or imply writing a new controller. This new or updated controller can use either existing or newly written services to fullfil it's role.

For further details on the micro-service's architecture please check the [documentation](https://github.com/sonata-nfv/tng-gtk-sp/wiki/micro-service-architecture).

### Submiting changes
Changes to the repository can be requested using [this repository's issues](https://github.com/sonata-nfv/tng-gtk-sp/issues) and [pull requests](https://github.com/sonata-nfv/tng-gtk-sp/pulls) mechanisms.

## Versioning

The most up-to-date version is v4. For the versions available, see the [link to tags on this repository](https://github.com/sonata-nfv/tng-gtk-sp/releases).

## Configuration
The configuration of the micro-service is done through the following environment variables, defined in the [Dockerfile](https://github.com/sonata-nfv/tng-gtk-sp/blob/master/Dockerfile):

* `CATALOGUE_URL`, which defines the Catalogue's URL, where test descriptors are fetched from;
* `REPOSITORY_URL`, which defines the Repository's URL, where test plans and test results are fetched from;
* `DATABASE_URL`,  which defines the database's URL, in the following format: `postgresql://user:password@host:port/database_name` (**Note:** this is an alternative format to the one described in the [Installing from the Docker container](#installing-from-the-Docker-container) section);
* `MQSERVER_URL`,  which defines the message queue server's URL, in the following format: `amqp://user:password@host:port`

## Tests
Unit tests are defined for both `controllers` and `services`, in the `/spec` folder. Since we use `rspec` as the test library, we configure tests in the [`spec_helper.rb`](https://github.com/sonata-nfv/tng-gtk-sp/blob/master/spec/spec_helper.rb) file, also in the `/spec` folder.

These tests are executed by running the following command:
```shel
$ bundle exec rspec spec
```

Wider scope (integration and functional) tests involving this micro-service are defined in [`tng-tests`](https://github.com/sonata-nfv/tng-tests).

## Style guide
Our style guide is really simple:

1. We try to follow a [Clean Code](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882) philosophy in as much as possible, i.e., classes and methods should do one thing only, have the least number of parameters possible, etc.;
1. we use two spaces for identation.

## API Reference

We have specified this micro-service's API in a [swagger](https://github.com/sonata-nfv/tng-gtk-sp/blob/master/doc/swagger.json)-formated file. Please check it there.

## Licensing

This 5GTANGO component is published under Apache 2.0 license. Please see the [LICENSE](https://github.com/sonata-nfv/tng-gtk-sp/blob/master/LICENSE) file for more details.
