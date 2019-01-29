ruleset io.picolabs.twilio_test {
  meta {
    name "Twilio Test"
    description <<
      This ruleset test the Twilio Module for Lab 2: APIs and Picos
    >>
    author "Art Macias"
    logging on
    
    // configure using account_sid = ""
    //                 auth_token  = ""
    provides
        send_sms, messages
        
    shares __testing
  }
  
  global {
    
    __testing = { 
        "events": [ 
          { "domain": "test", "type": "new_message", "attrs": [ "to", "from", "message" ] },
          { "domain": "test", "type": "get_message", "attrs": [ "pageSize", "to", "from" ] },
          { "domain": "test", "type": "get_message", "attrs": []}
        ]
    }
    
    send_sms = defaction(to, from, message) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
      http:post(base_url + "Messages.json", form =
                {"From":from,
                 "To":to,
                 "Body":message
                })
      }
      
    messages = defaction(pageSize, to, from) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
      response = http:get(base_url + "Messages.json", 
              qs = { "pageSize" : pageSize,
                      "to"       : to,
                      "from"     : from
                }){"content"}.decode();
      send_directive("Messages Response", {"Message said...": response})
      }
      
  }
}

