ruleset twilio {
  meta {
    name "Twilio Module"
    description <<
      The ruleset for Lab 2: APIs and Picos
    >>
    author "Art Macias"
    logging on
    shares __testing
  }

  global {
    
    send_sms = defaction(to, from, message, account_sid, auth_token) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
      http:post(base_url + "Messages.json", form =
                {"From":from,
                 "To":to,
                 "Body":message
                })
    }
    
    __testing = { 
      "queries": [ ],
      "events": [ ]
    }
  }
  
  rule test_send_sms {
   select when test new_message
    send_sms(event:attr("to"),
             event:attr("from"),
             event:attr("message"),
             event:attr("account_sid"),
             event:attr("auth_token"))
  }
}
