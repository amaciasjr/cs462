ruleset io.picolabs.twilio_module {
  meta {
    name "Twilio Module"
    description <<
      The ruleset for Lab 2: APIs and Picos
    >>
    author "Art Macias"
    logging on
    
    
    use module io.picolabs.twilio_keys
    use module io.picolabs.twilio_test alias twilio_secrets 
        with account_sid = keys:twilio_secrets{ "account_sid" }
             auth_token =  keys:twilio_secrets{ "auth_token" }
  }
  
  rule test_send_sms {
    select when test new_message
    twilio_secrets:send_sms (event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }
}
