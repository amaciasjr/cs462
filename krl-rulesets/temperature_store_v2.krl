ruleset temperature_store_v2 {
  meta {
    shares __testing, temperatures, threshold_violations, inrange_temperatures, current_temperature
    
    provides temperatures, threshold_violations, inrange_temperatures, current_temperature
    
    use module wovyn_base alias wovyn
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [   { "domain": "sensor", "type": "reading_reset" }
        //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    default_time = "00:00"
    clear_temperature ={ "temp_obj" : { "temperature": "0.0", "timestamp": "00:00" } }
    starting_id = 0
    
    // Returns the contents of the current_temperature entity variable.
    current_temperature = function() {
      ent:current_temperature.defaultsTo(0)
    };
    
    // Returns the contents of the temperature entity variable.
    temperatures = function() {
      ent:all_temps.defaultsTo([])
    };
    
    // Returns the contents of the threshold violation entity variable.
    threshold_violations = function() {
      ent:violations.defaultsTo([])
    };
    
    // Returns all the temperatures in the temperature entity variable that 
    // aren't in the threshold violation entity variable. 
    // (Note: You are expected to solve this without adding a rule that 
    // collects in-range temperatures)
    inrange_temperatures = function() {
      inrange_temps = ent:all_temps.filter(function(obj){ wovyn:temperature_threshold > obj{["temperature"]}.klog("OBJ TEMP: " ) });
      inrange_temps.klog("inrange_temps value: " )
    };
    
  }
  
  
  // Stores the temperature and timestamp event attributes in an entity variable. 
  // The entity variable should contain all the temperatures that have been processed.
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre {
      current_time = event:attr("timestamp").klog("Wovyn:New Temp Reading Time ")
      passed_temperature = event:attr("temperature").defaultsTo("0")
      temp_obj = {"timestamp":current_time, "temperature" : passed_temperature}
    }
    // Action section
    send_directive(
      "collect_temperatures", {
        "temp_obj" : temp_obj
      }
    )
    // Postlude section
    always {
      ent:all_temps := temperatures().append([temp_obj]);
      ent:current_temperature := passed_temperature
    }
  }
  
  // Stores the violation temperature and a timestamp in a different 
  // entity variable that collects threshold violations.
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre {
      current_time = time:now().klog("Wovyn:Threshold Violation Time ")
      temperature_threshold = wovyn:temperature_threshold.klog("collect_threshold_violations temperature_threshold: ")
      passed_temperature = event:attr("temperature").defaultsTo("0")
      violation_obj = {"timestamp":current_time, "violation_temp" : passed_temperature}
    }
    if passed_temperature > temperature_threshold then
    send_directive("ADDING TEMP VIOLATION TO ENT Variable")
    // Action section
    // Postlude section
    fired {
      ent:violations := threshold_violations().append(violation_obj)
    }
  }
  
  // Resets both of the entity variables from the collect_temperatures and
  // collect_threshold_violations rules.
  rule clear_temperatures {
    select when sensor reading_reset
    pre {
      current_time = time:now().klog("Wovyn:Reading Reset Time ")
    }
    // Action section
    // Postlude section
    always {
      clear ent:all_temps;
      clear ent:violations;
      
    }
  }
}

