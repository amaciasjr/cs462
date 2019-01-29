ruleset io.picolabs.twilio_module {
  meta {
    name "Twilio Module"
    description <<
      The ruleset for Lab 2: APIs and Picos
    >>
    author "Art Macias"
    logging on
    
    use module io.picolabs.twilio_keys
    use module io.picolabs.twilio_test alias twilio
        with account_sid = keys:twilio_secrets{ "account_sid" }
             auth_token =  keys:twilio_secrets{ "auth_token" }
  }
  
  rule test_send_sms {
    select when test new_message
    pre {
      to = event:attr("to").klog("our passed in to value: ")
      from = event:attr("from").klog("our passed in from value: ")
      message = event:attr("message").klog("our passed in message value: ")
    }
    every {
      send_directive("****TESTING SEND MESSAGE: to VALUE****", {"to":to});
      send_directive("****TESTING SEND MESSAGE: From VALUE****", {"from":from});
      send_directive("****TESTING SEND MESSAGE: message VALUE****", {"Message": message});
      twilio:send_sms (event:attr("to"), event:attr("from"), event:attr("message"))
    }
   
  }
  
  rule test_view_messages {
    select when test get_message
    pre {
      pageSize = event:attr("pageSize").defaultsTo("NO PAGE_SIZE").klog("our passed in pageSize value: ");
      to = event:attr("to").defaultsTo("NO Reciever").klog("our passed in to value: ");
      from = event:attr("from").defaultsTo("NO Sender").klog("our passed in from value: ");
    }
    every{
      send_directive("****TESTING GET MESSAGE - pageSize****", {"pageSize":pageSize})
      send_directive("****TESTING GET MESSAGE - to****", {"to":to})
      send_directive("****TESTING GET MESSAGE - from****", {"from":from})
      twilio:messages (event:attr("pageSize"), event:attr("to"), event:attr("from")) setting (content)
      // send_directive("****TESTING GET MESSAGE - from****", {"Response":response})
    }
  }
}

