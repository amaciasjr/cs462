ruleset manage_sensors_lab8 {
  meta {
    shares __testing, nameFromID, showChildren, all_temps, sensorCollection, last_five_temp_reports
    
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
    
    sensorTempReports = function() {
      ent:temp_reports.defaultsTo({})
    }
    
    // A function that returns a JSON structure with the five latest collection temperature reports.
    last_five_temp_reports = function() {
      temp_reports = sensorTempReports(); 
      temp_report0 = [];
      recent_keys = sensorTempReports().keys().sort(function(a, b) {
                            a > b  => -1 |
                            a == b =>  0 |
                                      1
                          }).slice(0,4).klog();
      recent_keys;
      temp_report1 = temp_report0.append(temp_reports{recent_keys[0]});
      temp_report2 = temp_report1.append(temp_reports{recent_keys[1]});
      temp_report3 = temp_report2.append(temp_reports{recent_keys[2]});
      temp_report4 = temp_report3.append(temp_reports{recent_keys[3]});
      five_most_recent_reports = temp_report4.append(temp_reports{recent_keys[4]});
      five_most_recent_reports
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
    
    genCorrelationNum = function() {
      random:uuid()
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
           "attrs": { "rids": ["temperature_store_v2", "wovyn_base_lab8", "sensor_profile"] } } )
      
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
  
  // This rule sends an event to each sensor pico (and only sensors) in 
  // the collection notifying them that a new temperature report is needed.
  rule start_seonsors_temp_report {
    select when sensor_manager sensors_temp_report
      foreach subscription:established("Tx_role","sensor").klog("SENSOR: ") setting (sensor)
      pre{
        temp_sensors = all_temps().length().klog("NUMBER OF TEMP SENSORS: ")
        my_tx = sensor{"Tx"};
        new_rcn = genCorrelationNum();
        rcn = event:attr("report_correlation_number").defaultsTo(new_rcn);
        updated_attrs = event:attrs.put(["report_correlation_number"], rcn);
        passing_obj = {}
        report_object = passing_obj.put([rcn], {"report_start_time": time:now(),"temperature_sensors": temp_sensors , "responding": 0, "temperatures": {}}).klog("Report OBJ 1: ")
        final_attrs = updated_attrs.put(report_object)
      }
      event:send(
        { "eci": my_tx, "eid": "sensor_temp_report",
          "domain": "sensor", "type": "temp_report",
          "attrs": final_attrs } )
      fired {
        ent:temp_reports := sensorTempReports().put(report_object).klog("TEMP REPORT Val 1: ");
      }
  }
  
  rule seonsors_temp_report_received {
    select when sensor_manager receive_temp_report
    pre {
      temp_reports = ent:temp_reports
      rcn = event:attr("report_correlation_number");
      temp_report = event:attr("temp_report");
      curr_report = temp_reports{rcn};
      report_started = curr_report{"report_start_time"};
      total_sensors_in_report = curr_report{"temperature_sensors"};
      new_temperatures = curr_report{"temperatures"}.put(temp_report);
      new_resp_val = curr_report{"responding"} + 1;
      holder_obj = {};
      report_object = holder_obj.put([rcn], {"report_start_time": report_started,"temperature_sensors": total_sensors_in_report , "responding": new_resp_val, "temperatures": new_temperatures }).klog("Report OBJ 2: ")
    }
    fired {
      ent:temp_reports := sensorTempReports().put(report_object).klog("TEMP REPORT Val 2: ");
    }
    
  }
}

