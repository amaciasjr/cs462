ruleset manage_sensors_lab7 {
  meta {
    shares __testing, nameFromID, showChildren, sensorCollection
    
    use module io.picolabs.wrangler alias wrangler
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
    };
    
    send_to_num = +13039018143
    default_threshold = 70
    
  }
  
  rule sensor_already_exists {
    select when sensor new_sensor
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
    select when sensor new_sensor
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
                     "color": "#e612e6",
                     "sensor_name": sensor_name }
    }
  }
  
  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      the_sensor = {"eci": event:attr("eci")}
      sensor_name = event:attr("rs_attrs"){"sensor_name"}
    }
    if sensor_name.klog("found sensor_name")
    then
      event:send(
         { "eci": the_sensor{"eci"}, "eid": "install-ruleset",
           "domain": "wrangler", "type": "install_rulesets_requested",
           "attrs": { "rids": ["temperature_store_v2", "wovyn_base", "sensor_profile"] } } )
    fired {
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
      ent:updated_sensors := ent:updated_sensors.defaultsTo({});
      ent:updated_sensors{[sensor_name]} := the_sensor
    }
  }
  
  rule sensor_removed {
    select when sensor unneeded_sensor
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

