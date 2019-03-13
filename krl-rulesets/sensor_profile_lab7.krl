ruleset sensor_profile {
  meta {
    shares __testing, sensor_location, sensor_name, sensor_threshold, notify_who
    provides sensor_threshold
    use module wovyn_base alias wovyn
  }
  
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    default_location = "Provo"
    
    sensor_location = function() {
      ent:sensor_loc.defaultsTo(default_location)
    };
    
    sensor_name = function() {
      ent:sensor_name.defaultsTo(wovyn:name)
    };
    
    sensor_threshold = function() {
      ent:sensor_threshold.defaultsTo(wovyn:threshold)
    };
    
    notify_who = function() {
      ent:num_to_notify.defaultsTo(wovyn:notify_number)
    };
    
  }
  
  rule profile_updated {
    select when sensor profile_updated
    pre {
      passed_threshold = event:attr("threshold").defaultsTo(sensor_threshold())
      passed_number = event:attr("send_to").defaultsTo(notify_who()) 
      passed_location = event:attr("location").defaultsTo(sensor_location())
      passed_name = event:attr("name").defaultsTo(sensor_name())
    }
    always {
      ent:sensor_loc := passed_location;
      ent:sensor_threshold := passed_threshold;
      ent:sensor_name := passed_name;
      ent:num_to_notify := passed_number
    }
  }
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    pre {
      attributes = event:attrs.klog("subcription:")
    }
    always {
      raise wrangler event "pending_subscription_approval"
        attributes attributes
    }
  }
}
