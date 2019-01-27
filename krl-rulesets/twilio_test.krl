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
        send_sms
  }
  
  global {
    send_sms = defaction(to, from, message) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
      http:post(base_url + "Messages.json", form =
                {"From":from,
                 "To":to,
                 "Body":message
                })
      }
  }
}

