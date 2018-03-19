# 5GTANGO API Gateway
This is the 5GTANGO Gatekeeper Service Platform specific components repository .

[![Build Status](https://jenkins.sonata-nfv.eu/buildStatus/icon?job=tng-api-gtw/master)](https://jenkins.sonata-nfv.eu/job/tng-api-gtw/master)
[![Join the chat at https://gitter.im/5gtango/tango-schema](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/5gtango/tango-schema)

<p align="center"><img src="https://github.com/sonata-nfv/tng-api-gtw/wiki/images/sonata-5gtango-logo-500px.png" /></p>

This component holds all the micro-services of the Gatekeeper that will be available only to the Service Platform (and not to the V&ampersendV Platform).

## Installing / Getting started

This component is implemented in [ruby](https://www.ruby-lang.org/en/) (we're using version **2.4.3**). To have it up and running, please do the follwoing:

```shell
$ git clone https://github.com/sonata-nfv/tng-gtk-sp.git # Clone this repository
$ cd tng-gtk-sp # Go to the newly created folder
$ bundle install # Install dependencies
$ bundle exec rspec spec # Execute tests
$ PORT=5350 bundle exec rackup # Run the server
```

Everything being fine, you'll have a server running on that session, on port `5350`. You can use it by using `curl`, like in:

```shell
$ curl <host name>:5350/
```

## Developing
Development in this component is done by using [ruby](https://www.ruby-lang.org/en/), version 2.4.3, and the following libraries (also referenced in the `Gemfile`):

----
Still a Work-in-Progress from here down

### Built With
List main libraries, frameworks used including versions (React, Angular etc...)

### Prerequisites
What is needed to set up the dev environment. For instance, global dependencies or any other tools. include download links.


### Setting up Dev

Here's a brief intro about what a developer must do in order to start developing
the project further:

```shell
git clone https://github.com/your/your-project.git
cd your-project/
packagemanager install
```

And state what happens step-by-step. If there is any virtual environment, local server or database feeder needed, explain here.

### Building

If your project needs some additional steps for the developer to build the
project after some code changes, state them here. for example:

```shell
./configure
make
make install
```

Here again you should state what actually happens when the code above gets
executed.

### Deploying / Publishing
give instructions on how to build and release a new version
In case there's some step you have to take that publishes this project to a
server, this is the right time to state it.

```shell
packagemanager deploy your-project -s server.com -u username -p password
```

And again you'd need to tell what the previous code actually does.

## Versioning

We can maybe use [SemVer](http://semver.org/) for versioning. For the versions available, see the [link to tags on this repository](/tags).


## Configuration

Here you should write what are all of the configurations a user can enter when
using the project.

## Tests

Describe and show how to run the tests with code examples.
Explain what these tests test and why.

```shell
Give an example
```

## Style guide

Explain your code style and show how to check it.

## Api Reference

If the api is external, link to api documentation. If not describe your api including authentication methods as well as explaining all the endpoints with their required parameters.


## Database

Explaining what database (and version) has been used. Provide download links.
Documents your database design and schemas, relations etc... 

## Licensing

State what the license is and how to find the text version of the license.
