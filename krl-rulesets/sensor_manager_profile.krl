ruleset sensor_manager_profile {
  meta {
    shares __testing, send_to_number, send_from_number, message_to_send
    
    use module io.picolabs.twilio_keys
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.twilio_test alias twilio
        with account_sid = keys:twilio_secrets{ "account_sid" }
             auth_token =  keys:twilio_secrets{ "auth_token" }
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    send_to_number = function() {
      ent:manager_to_num.defaultsTo("+13039018143")
    };
    
    send_from_number = function() {
      ent:manager_from_num.defaultsTo("+17206056876")
    };
    
    message_to_send = function() {
      ent:manager_message.defaultsTo("Message from " + wrangler:myself(){"name"})
    };
  }
  
  rule manager_send_sms {
    select when sensor_manager new_message
    pre {
      to = event:attr("to").defaultsTo(send_to_number())
      from = event:attr("from").defaultsTo(send_from_number())
      message = event:attr("message").defaultsTo(message_to_send())
    }
    twilio:send_sms (to, from, message)
   
  }
}
