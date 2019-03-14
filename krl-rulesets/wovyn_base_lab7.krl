ruleset wovyn_base_lab7 {
  meta {
    shares __testing, location, name, threshold, notify_number
    provides threshold, notify_number, location, name
    
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
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
    temp_location = "Provo"
    temp_name = "Wovyn_16703A"
    
    threshold = function() {
      ent:sensor_threshold.defaultsTo(temperature_threshold)
    };
    
    location = function() {
      ent:sensor_loc.defaultsTo("Unknown Location")
    };
    
    name = function() {
      ent:sensor_name.defaultsTo("No Name")
    };
    
    notify_number = function() {
      ent:sensor_to.defaultsTo(send_to_num)
    };
    
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat
    // PRELUDE SECTION
    pre {
      never_used = event:attrs.klog("ALL attrs")
      // has_genericThing = event:attr("genericThing").klog("GENERIC THING INFO: ")
      current_time = time:now()
      given_location = location => event:attrs{["property", "location", "description"]} | location()
      given_name = name => event:attrs{["property", "name"]} | name()
      has_temp_array = event:attrs{["genericThing", "data", "temperature"]}.klog("Temperature ARRAY INFO: ")
      temp = has_temp_array[0]{"temperatureF"}
    }
    // ACTION SECTION
    if temp then
      send_directive("Wovyn Info", {"info":never_used})
      
    // POSTLUDE SECTION
    fired {
      ent:sensor_loc := given_location;
      ent:sensor_name := given_name;
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
      subscription_role = subscription:established[0]{"Tx_role"}
      sensor_manager_eci = subscription:established[0]{"Tx"}
      subscription_id = subscription:established[0]{"Id"}
    }
    
    // ACTION SECTION
    if subscription_role == "sensor_manager"
    then
      event:send(
           { "eci": sensor_manager_eci, "eid": "threshold-violation",
             "domain": "sensor_manager", "type": "threshold_violation",
             "attrs": { "to": send_to_num,
                      "from": send_from_num,
                      "message": "Message from " + wrangler:myself(){"name"} } } )

    // POSTLUDE SECTION
    fired {
    }
  }
  
  rule profile_updated {
    select when sensor profile_updated
    // PRELUDE SECTION
    pre {
      passed_threshold = event:attr("threshold") => event:attr("threshold") | threshold()
      passed_number = event:attr("send_to") => event:attr("send_to") | notify_number()
      passed_location = event:attr("location") => event:attr("location") | notify_number()
      passed_name = event:attr("name") => event:attr("name") | notify_number()
      temp = event:attr("temperature")
      current_time = time:now()
    }
    send_directive("Threshold Updateded")
    // ACTION SECTION
    
    // POSTLUDE SECTION
    always {
      ent:sensor_threshold := passed_threshold;
      ent:sensor_to := passed_number;
      ent:sensor_loc := passed_location;
      ent:sensor_name := passed_name;
      raise wovyn event "threshold_violation"
          attributes event:attrs
    }
  }
}
