require 'sinatra'
require 'sinatra/config_file'
require 'haml'
require 'newrelic_rpm'
require 'amqp'
require 'mongo'
require 'bson'
require 'titan'
require './lib/hl7helpers'
require './inbound'
include HL7Server

class App < Sinatra::Base
  register Sinatra::ConfigFile
  config_file 'config/settings.yml'
  
  @@tcp_socket = nil
  
  get '/' do
    thread = Titan::Thread.find("Outbound HL7")
    if thread != nil
      if thread.alive?
        @outbound = true
      else
        @outbound = false
      end
    else
      @outbound = false
    end
    
    thread = Titan::Thread.find("Inbound HL7")
    if thread != nil
      if thread.alive?
        @inbound = true
      else
        @inbound = false
      end
    else
      @inbound = false
    end
    
    haml :index
  end
  
  get '/start_outbound' do
    if @@tcp_socket != nil
      @@tcp_socket.close
    end
    @@tcp_socket = TCPSocket.open(settings.hl7_output_ip, settings.hl7_output_port)
      
    thread = Titan::Thread.new do
      EventMachine.run do
        # Set up the RabbitMQ AQMP connection to subscribe to
        aqmp_connection = AMQP.connect(:host => settings.rabbitmq_address)
        channel = AMQP::Channel.new(aqmp_connection)
        queue = channel.queue(settings.rabbitmq_channel)
        exchange = channel.direct("")

        # Set up the MongoDB connection for retrieving the records
        db = Mongo::MongoClient.new(settings.mongo_ip, settings.mongo_port).db(settings.mongo_db)
        collection = db.collection(settings.mongo_collection)
  
        # Start the queue subscription loop
        queue.subscribe do |message|
          # Retrieve the visit from the db
          item = collection.find_one("_id" => message)

          # Convert it to an HL7 message using the helper file
          message = HL7Helpers::to_hl7(item)

          # Send it to the HL7 endpoint
          @@tcp_socket.write message
        end
      end
    end
    thread.run
    thread.id = "Outbound HL7"
    redirect '/'
  end
  
  get '/stop_outbound' do
    thread = Titan::Thread.find("Outbound HL7")
    if thread != nil
      thread.kill if thread.alive?
      Titan::Thread.remove_dead_threads
    end
    if @@tcp_socket != nil
      @@tcp_socket.close
      @@tcp_socket = nil
    end
    redirect '/'
  end
  
  get '/start_inbound' do
    thread = Titan::Thread.new do
      EventMachine.run do
        EventMachine.start_server("0.0.0.0", settings.hl7_input_port, HL7Server)
      end
    end
    thread.run
    thread.id = "Inbound HL7"
    redirect '/'
  end
  
  get '/stop_inbound' do
    thread = Titan::Thread.find("Inbound HL7")
    if thread != nil
      thread.kill if thread.alive?
      Titan::Thread.remove_dead_threads
    end
    redirect '/'
  end
  
end