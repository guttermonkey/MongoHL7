require 'eventmachine'
require 'ruby-hl7'
require 'mongo'
require 'bson'
require './lib/hl7helpers'

module HL7Server
  def post_init
    # Set up the MongoDB connection for retrieving the records
    db = Mongo::MongoClient.new("10.1.23.202", 27017).db("halcyon_mongo_development")
    visits = db.collection("visits")
  end
  
  def receive_data data
    # Strip out the Windows carriage returns and rebuild the message
    segments = eval(data.inspect).split("\r")
    message = HL7::Message.new
    if segments[0] != nil
      msh = HL7::Message::Segment::MSH.new(segments[0])
      message << msh
    end
    if segments[1] != nil
      pid = HL7::Message::Segment::PID.new(segments[1])
      message << pid
    end
    if segments[2] != nil
      pv1 = HL7::Message::Segment::PV1.new(segments[2])
      message << pv1
    end
    if segments[3] != nil
      orc = HL7::Message::Segment::ORC.new(segments[3])
      message << orc
    end
    if segments[4] != nil
      obr = HL7::Message::Segment::OBR.new(segments[4])
      message << obr
    end
    
    # Find the message type & code
    message_type = message[:MSH].e8.split('^')[0]
    message_code = message[:MSH].e8.split('^')[1]

    if message_type == "ORM"
      
      if message[:ORC].e1.match(/^CA/)
        # Deletion message, remove from db
        visits.remove("_id" => message[:OBR].e2)
      
      else
        # New appointment message, create new record in db.
        visit = HL7Helpers::from_hl7(message)
        visits.update({"_id" => message[:OBR].e2}, visit, :upsert => true)
      end
      
    elsif message_type == "ADT" && message_code != "A34"
      # Update message
      visit = HL7Helpers::from_hl7(message)
        visits.update({"_id" => message[:OBR].e2}, visit, :upsert => true)
      
    elsif message_type == "ADT"
      # Update MRN only message, should affect all instances of mrn
      visits.update({"_id" => message[:MRG].e0}, {"$set" => {"mrn" => message[:PID].e3}})
    end

    # Acknowledge receipt to CorePoint
    ack_msg = HL7::Message.new
    msh = HL7::Message::Segment::MSH.new("MSH|^~\\&|HALCYON|Radiology Ltd|||||ACK|#{message[:MSH].e9}|P|2.3||||NE|")
    msa = HL7::Message::Segment::MSA.new("MSA|AA||MSG OK|")
    ack_msg << msh << msa
    send_data ack_msg.to_mllp
  end
end