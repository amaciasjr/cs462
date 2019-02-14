ruleset wovyn_base {
  meta {
    shares __testing
    provides temperature_threshold
  }
  global {
    __testing = { 
      "queries": 
      [ 
        { "name": "__testing" } 
      ],
      "events": 
      [ 
        { "domain": "wovyn", "type": "heartbeat", "attrs": [ "temp", "baro" ] } 
      ] 
    }
    
    temperature_threshold = 70
    send_to_num = "+13039018143"
    send_from_num = "+17206056876"
    
    
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat
    // PRELUDE SECTION
    pre {
      never_used = event:attrs.klog("ALL attrs")
      // has_genericThing = event:attr("genericThing").klog("GENERIC THING INFO: ")
      current_time = time:now()
      has_temp_array = event:attrs{["genericThing", "data", "temperature"]}.klog("Temperature ARRAY INFO: ")
      temp = has_temp_array[0]{"temperatureF"}
    }
    // ACTION SECTION
    if temp then
      send_directive("Wovyn Info", {"info":never_used})
      
    // POSTLUDE SECTION
    fired {
      // raise <domain> event <"type">
      raise wovyn event "new_temperature_reading"
        attributes { "temperature": temp, "timestamp": current_time }
    }
    else{
      
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    // PRELUDE SECTION
    pre {
      //
      curr_temp = event:attr("temperature").klog("THIS IS NEW TEMP READING TEMP: ")
    }
    if curr_temp > temperature_threshold then
      send_directive("TEMP VIOLATION")
    // ACTION SECTION
    
    // POSTLUDE SECTION
    fired {
      raise wovyn event "threshold_violation"
        attributes event:attrs
    }
    else{
      
    }
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    // PRELUDE SECTION
    pre {
      
    }
    send_directive("SENDING MESSAGE AFTER VIOLATION")
    // ACTION SECTION
    
    // POSTLUDE SECTION
    fired {
      raise test event "new_message"
        attributes { "to": send_to_num, "from": send_from_num, "message" : "KENT is it hot in the living room? - Art" }
    }
    else{
      
    }
  }
}

