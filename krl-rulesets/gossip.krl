ruleset gossip {
  meta {
    shares __testing
    
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    // functions: generate_gossip_message(), get_peer(), update_logs(),
    // get_my_logs(),
    get_sequence_number = function() {
      ent:message_number => ent:message_number | 0
    }
    
    get_all_gossip = function() {
      ent:gossip_messages => ent:gossip_messages | []
    }
    
    generate_gossip_message = function( picoId, temperature, timestamp  ) {
      message_id = picoId + ":" + get_sequence_number().as("String");
      gossip_message = {
        "MessageID": message_id,
        "SensorID": picoId,
        "Temperature": temperature,
        "Timestamp": timestamp
      };
      gossip_message
    }
    
    
    // Entity varibles: all_logs, "smart_tracker" = only peer seen massages,
    // implement the smart tracker with a root map that has originator of message
    // keyed to an array that contains a sequence of messages.
  }
  
  // This rule listens for new temperature readings,
  // then generate new log to added to your 
  rule new_temp_recieved {
    select when gossip new_temp
    pre {
      my_pico_id     = meta:picoId.klog("Pico ID: ");
      temp_received  = (event:attr("temperature") => event:attr("temperature") | null).klog("Received Temp: "); 
      time_received  = time:now().klog("Time Received: "); 
      gossip_message = generate_gossip_message(my_pico_id, temp_received, time_received);
    }
    // Check if gossip_message was created.
    if gossip_message
      then noop()
    
    fired {
      ent:gossip_messages := get_all_gossip().append(gossip_message)
    }
    else {
      
    }
  }
  
  // This needs to be a scheduled event that happens periodically.
  // Also, needs to send message typ randomly (use random library).
  rule gossip_heartbeat_happened {
    select when gossip heartbeat
    pre {}
    //action:
    fired{
      
    }
    else{
      
    }
  }
  
  // Rule that 
  rule rumor_message_received {
    select when gossip rumor_message
    pre {}
    //action:
    fired{
      
    }
    else{
      
    }
  }
  
  rule seen_message_received {
    select when gossip seen_message
    pre {}
    //action:
    fired{
      
    }
    else{
      
    }
  }
  
}

