require './lib/gt1'
require 'ruby-hl7'
require 'mongo'
require 'bson'

module HL7Helpers
  def to_hl7(visit)
    message = HL7::Message.new
    timenow = Time.now.strftime("%Y%m%d%H%M%S")
    msh = HL7::Message::Segment::MSH.new("MSH|^~\\&|Halcyon|Radiology Ltd|||#{timenow}||ADT^A08|#{visit['_id']}|P|2.3||||NE|")
    message << msh
    pid = HL7::Message::Segment::PID.new
    pid.e3 = visit['mrn']
    middle = visit['middle_name'].upcase if visit['middle_name']
    pid.e5 = "#{visit['last_name'].upcase}^#{visit['first_name'].upcase}^#{middle}^"
    dob = visit['dob'].strftime("%Y%m%dT%H%M") if visit['dob']
    pid.e7 = dob.split("T").first
    pid.e8 = visit['sex']
    pid.e10 = visit['race']
    pid.e11 = "#{visit['address1'].upcase}^#{visit['address2'].upcase}^#{visit['city'].upcase}^#{visit['state'].upcase}^#{visit['zip']}"
    pid.e13 = "#{visit['phone']}^^^#{visit['email']}"
    pid.e14 = visit['work_phone']
    pid.e15 = visit['language_code']
    pid.e16 = visit['marital_status_code']
    pid.e19 = visit['ssn']
    pid.e22 = visit['ethnicity_code']
    message << pid
    pv1 = HL7::Message::Segment::PV1.new
    pv1.e5 = visit['visit_id']
    pv1.e52 = "#{visit['weight']}^#{visit['height']}^#{visit['blood_pressure']}^#{visit['smoking_status']}"
    message << pv1
    gt1 = HL7::Message::Segment::GT1.new
    gt1.e3 = "#{visit['guarantor_last']}^#{visit['guarantor_first']}^#{visit['guarantor_middle']}^"
    gt1.e5 = "#{visit['guarantor_address1']}^^#{visit['guarantor_city']}^#{visit['guarantor_state']}^#{visit['zip']}"
    gt1.e6 = visit['guarantor_phone']
    gt1.e7 = visit['guarantor_work_phone']
    gt1.e8 = visit['guarantor_dob'].strftime("%Y%m%d") if visit['guarantor_dob']
    gt1.e9 = visit['guarantor_sex']
    gt1.e10 = visit['guarantor_type']
    message << gt1
    return message.to_mllp
  end
  
  def from_hl7(data)
    message = HL7::Message.new(eval(data.inspect))
    
    # Ruby doesn't like to split nil strings, so making some variables
    if message[:PID].e13 != nil
      contactinfo = message[:PID].e13.split('^')
      phone = contactinfo[0]
      if contactinfo[3] != nil
        email = contactinfo[3]
      else
        email = ""
      end
    else
      phone = "".to_i
      email = ""
    end
    
    if message[:PID].e16 != nil
      marital = message[:PID].e16.split('^')
      marital_status_code = marital[0]
      if marital[1] != nil
        marital_status = marital[1]
      else
        marital_status = ""
      end
    else
      marital_status_code = ""
      marital_status = ""
    end
    
    site = message[:ORC].e13.split('^')[3]
    if site == "RLCMR"
      site = "RLC"
    end
    
    visit = {
      "_id" => message[:ORC].e2,
      "patientId" => message[:PID].e2,
      "mrn" => message[:PID].e3,
      "last_name" => message[:PID].e5.split('^')[0],
      "first_name" => message[:PID].e5.split('^')[1],
      "middle_name" => message[:PID].e5.split('^')[2],
      "dob" => Date.strptime(message[:PID].e7, '%Y%m%d'),
      "sex" => message[:PID].e8,
      "ethnicity" => message[:PID].e10,
      "address1" => message[:PID].e11.split('^')[0],
      "address2" => message[:PID].e11.split('^')[1],
      "city" => message[:PID].e11.split('^')[2],
      "state" => message[:PID].e11.split('^')[3],
      "zip" => message[:PID].e11.split('^')[4],
      "phone" => phone,
      "email" => email,
      "work_phone" => message[:PID].e14,
      "marital_status_code" => marital_status_code,
      "marital_status" => marital_status,
      "ssn" => message[:PID].e19,
      "employer" => message[:PID].e23,
      "visit_id" => message[:ORC].e4,
      "site" => site,
      "visit_id" => message[:ORC].e4,
      "exam_code" => message[:OBR].e4.split('^')[0],
      "exam_desc" => message[:OBR].e4.split('^')[1],
      "symptoms" => message[:OBR].e31,
      "referring_code" => message[:OBR].e16.split('^')[0],
      "referring_first_name" => message[:OBR].e16.split('^')[1],
      "referring_last_name" => message[:OBR].e16.split('^')[2],
      "referring_middle" => message[:OBR].e16.split('^')[3],
      "referring_phone" => message[:OBR].e17.split('^')[0],
      "referring_fax" => message[:OBR].e17.split('^')[1],
      "modality" => message[:OBR].e24,
      "appointment" => DateTime.strptime(message[:OBR].e36 + ' -0700', "%Y%m%d%H%M%S %Z")
    }
    
    return visit
  end

  module_function :to_hl7
  module_function :from_hl7
end
