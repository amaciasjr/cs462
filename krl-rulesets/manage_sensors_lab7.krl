ruleset manage_sensors_lab7 {
  meta {
    shares __testing, nameFromID, showChildren, all_temps, sensorCollection
    
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries": [{ "name": "__testing" },
                              {"name": "showChildren"},
                              {"name": "sensorCollection"}],
                  "events": [ { "domain": "sensor", "type": "new_sensor", "attrs": [ "sensor_name" ] },
                              { "domain": "sensor", "type": "offline", "attrs": [ "sensor_name" ] },
                              { "domain": "collection", "type": "empty", "attrs": [  ] }] }
    
    nameFromID = function(sensor_name) {
      sensor_name + " Sensor Pico"
    }
    
    showChildren = function() {
      wrangler:children()
    }
    
    sensorCollection = function() {
      ent:sensors.defaultsTo([])
    }
    
    // Updateded this function to use subscription info to find sensor picos.
    all_temps = function() {
      host = "http://localhost:8080";
      subscription:established().map(function(v,k) {
        subscription_id = v{"Id"};
        response = http:get(host + "/sky/cloud/" + v{"Tx"} + "/temperature_store_v2/current_temperature");
        answer = response{"content"}.decode();
        final_answer = {};
        final_answer.put(subscription_id, answer)
      })
    }
    
    send_to_num = +13039018143
    default_threshold = 70
    
  }
  
  rule sensor_already_exists {
    select when sensor_manager new_sensor
    pre {
      sensor_name = event:attr("name")
      exists = ent:sensors >< sensor_name
    }
    // Action Block
    if exists 
    then
      send_directive("name_ready", {"sensor_name": sensor_name})
  }
  
  rule sensor_created {
    select when sensor_manager new_sensor
    pre {
      sensor_name = event:attr("name")
      exists = ent:sensors >< sensor_name
    }
     // Action Block
    if not exists
    then
      noop()
    fired {
      raise wrangler event "child_creation"
        attributes { "name": nameFromID(sensor_name),
                     "color": "#f4a442",
                     "sensor_name": sensor_name }
    }
  }
  
  rule sensor_introduced {
    select when sensor_manager introduce_sensor
    pre {
      in_sensor_name = event:attr("name")
      in_sensor_eci = event:attr("eci")
    }
    if in_sensor_name.klog("found sensor_name")
    then
      noop()
    fired {
       raise wrangler event "subscription"
        attributes { "name": in_sensor_name,
                      "Rx_role": "sensor_manager",
                      "Tx_role": "sensor",
                      "channel_type": "subscription",
                      "wellKnown_Tx": in_sensor_eci };
    }
  }
  
  rule sensor_threshold_violation {
    select when sensor_manager threshold_violation
    pre {
      to = event:attr("to").klog("sensor_threshold_violation to: ")
      from = event:attr("from").klog("sensor_threshold_violation from: ")
      message = event:attr("message").klog("sensor_threshold_violation message: ")
    }
    if message then
      noop()
    fired{
      raise sensor_manager event "new_message"
         attributes { "to": to,
                      "from": from,
                      "message": message };
    }
  }
  
  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      the_sensor = {"eci": event:attr("eci")}
      sensor_name = event:attr("rs_attrs"){"sensor_name"}
      sensor_eci = event:attr("eci")
    }
    if sensor_name.klog("found sensor_name")
    then
    event:send(
         { "eci": the_sensor{"eci"}, "eid": "install-ruleset",
           "domain": "wrangler", "type": "install_rulesets_requested",
           "attrs": { "rids": ["temperature_store_v2", "wovyn_base_lab7", "sensor_profile"] } } )
      
    fired {
       raise wrangler event "subscription"
        attributes { "name": sensor_name,
                      "Rx_role": "sensor_manager",
                      "Tx_role": "sensor",
                      "channel_type": "subscription",
                      "wellKnown_Tx": sensor_eci };
      ent:sensors := ent:sensors.defaultsTo({});
      ent:sensors{[sensor_name]} := the_sensor
    }
  }
  
  rule update_child_profile {
    select when wrangler child_initialized
    pre {
      the_sensor = {"eci": event:attr("eci")}
      sensor_name = event:attr("rs_attrs"){"sensor_name"}
    }
    if sensor_name.klog("found sensor_name")
    then
      event:send(
         { "eci": the_sensor{"eci"}, "eid": "install-ruleset",
           "domain": "sensor", "type": "profile_updated",
           "attrs": { "name": sensor_name, "send_to": send_to_num, "threshold":default_threshold} } )
    fired {
      // ent:updated_sensors := ent:updated_sensors.defaultsTo({});
      // ent:updated_sensors{[sensor_name]} := the_sensor
    }
  }
  
  rule sensor_removed {
    select when sensor_manager unneeded_sensor
    pre {
      sensor_name = event:attr("name")
      exists = ent:sensors >< sensor_name
      child_to_delete = nameFromID(sensor_name)
    }
    if exists then
      send_directive("deleting_sensor", {"sensor_name":sensor_name})
    fired {
      raise wrangler event "child_deletion"
        attributes {"name": child_to_delete};
      clear ent:sensors{[sensor_name]}
    }
  }
  
  rule collection_empty {
    select when collection empty
    always {
      ent:sensors := {}
    }
  }
   
  
}

