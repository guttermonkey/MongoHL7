MongoHL7
========

As part of a project at the office I needed to build a semi-robust [HL7](http://www.hl7.org)
messaging system.  The project takes an HL7 feed from a
[Corepoint Integration Engine](http://www.corepointhealth.com/products/corepoint-connections/corepoint-integration-engine)
to populate a MongoDB NoSQL database.  This database is then used by a Rails application and
a Sinatra application for various uses inside the company.  There are options from the endpoints
to send a modified record HL7 message back out to Corepoint for processing by other systems,
thus this application needed to support bidirectional HL7.

Web Interface
-------------
In order to make the interfaces easy to use, I've wrapped the project in Sinatra for start/stopping
the inbound and outbound feeds.  Within Sinatra I'm using a great gem called [Titan](https://github.com/flippingbits/titan)
to spawn the individual [EventMachine](https://github.com/eventmachine/eventmachine) based servers.

Inbound HL7
-----------
I'm using the [ruby-hl7](https://github.com/segfault/ruby-hl7) gem to parse the incoming HL7
messages as well as to construct the outbound messages.  I initially had some issues with the
fact that our Corepoint server is on Windows, so there's some stripping of \r and rebuilding of the
inbound messages going on before trying to match message types.  Once the message type is matched it
simply performs the required database operation.

Outbound HL7
------------
[RabbitMQ](http://www.rabbitmq.com/) is a great messaging system and this relies on the other
consumers of the database to queue up a message on RabbitMQ from which this application pops the
id of and constructs a new HL7 message based on that.

Other Notes
-----------
As is rather easy to notice, I decided to use HAML for the views, which I'm still getting used
to.  Other notes are that I'm using Capistrano to deploy, Unicorn to serve & NewRelic to monitor
this application in production