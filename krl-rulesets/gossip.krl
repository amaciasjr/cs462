ruleset gossip {
  meta {
    shares __testing, sequence_number, my_gossip, peers_logs, get_peers, temp_logs
    
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" },
        { "name": "sequence_number" },
        { "name": "my_gossip" },
        { "name": "get_peers" },
        { "name": "peers_logs" },
        { "name": "temp_logs" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "gossip", "type": "new_temp", "attrs": [ "temperature" ]  },
        { "domain": "gossip", "type": "heartbeat"}
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    // functions: generate_gossip_message(), get_peers(), update_logs(),
    // get_my_logs(),
    sequence_number = function() {
      ent:message_number => ent:message_number | 0
    }
    
    my_gossip = function() {
      ent:gossip_messages => ent:gossip_messages | []
    }
    
    temp_logs = function() {
      ent:temperature_logs => ent:temperature_logs | {}
    }
    
    heartbeat_time = function() {
      ent:heartbeat_time => ent:heartbeat_time | 15
    }
    
    rand_int = function(peers) {
      num_of_peers = peers.length().klog("# of Peers: ");
      rand_peer = random:integer(upper = num_of_peers-1, lower = 0);
      rand_peer
    }
    
    generate_seen_message = function() {
      
    }
    
    // Get specific rumor message(s) that a given peer needs.
    find_rumor_messages = function(peer_eci) {
      
    }
    
    generate_rumor_message = function( picoId, temperature, timestamp  ) {
      message_id = picoId + ":" + sequence_number().as("String");
      gossip_message = {
        "MessageID": message_id,
        "SensorID": picoId,
        "Temperature": temperature,
        "Timestamp": timestamp
      };
      gossip_message
    }
    
    peers_logs = function() {
      host = "http://localhost:8080";
      subscription:established().map(function(v,k) {
        subscription_id = v{"Id"};
        response = http:get(host + "/sky/cloud/" + v{"Tx"} + "/gossip/my_gossip");
        log = response{"content"}.decode();
        log_collection = {};
        log_collection.put(subscription_id, log)
      })
    }
    
    // get_peers() needs to return a "subscription eci" associated with the peer's PicoID
    get_peers = function() {
      // my_messages = get_my_gossip().klog("Current State: ");
      subscription:established().map(function(v,k) {
        subscription_Tx = v{"Tx"};
        subscription_Tx
      });
      
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
      rumor_message = generate_rumor_message(my_pico_id, temp_received, time_received);
    }
    // Check if rumor_message was created.
    if rumor_message
      then noop()
    
    fired {
      ent:gossip_messages := my_gossip().append(rumor_message);
      ent:message_number := sequence_number() + 1;
    }
    else {
      // DO NOTHING FOR NOW!
    }
  }
  
  // This needs to be a scheduled event that happens periodically.
  // Also, needs to send message type randomly (use random library).
  // SUDO CODE:
  //    when gossip_heartbeat {
  //      subscriber = getPeer(state)                    
  //      m = prepareMessage(state, subscriber)       
  //      send (subscriber, m)            
  //      update(state)     
  //    }
  
  rule gossip_heartbeat_happened {
    select when gossip heartbeat
    pre {
      // choose a peer to send a message to.
      subscribers = get_peers(); // returns a "subscription eci"
      rand_peer = rand_int(subscribers).klog("Random Peer #: ");
      rand_subscriber = subscribers[rand_peer].klog("Random Peer: ");
      updated_attrs = event:attrs.put(["subscriber"], rand_subscriber); // adds that peer to the event:attrs
      rand_message = random:integer(1)
    }
    //action:
    if rand_message == 1 then
      noop();
    fired{
      raise gossip event "send_rumor"
        attributes updated_attrs;
    }
    else{
      raise gossip event "send_seen"
        attributes updated_attrs;
    }
  }
  
  rule schedule_gossip_heartbeat {
    select when gossip schedule_heartbeat
    always{
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": heartbeat_time()})
        attributes event:attrs;
    }
  }
  
  // This rule needs to find the proper rumor message to send to the selected peer.
  rule send_rumor_message {
    select when gossip send_rumor
    pre {
      peer_eci = event:attr("subscriber").klog("Send Rumor to: ");
      rumor_messages = find_rumor_messages(peer_eci);
      updated_attrs = event:attrs.put(["message"], rumor_messages); // adds message to the event:attrs
    }
    event:send( { "eci": peer_eci, "eid": "send-rumor-message",
                  "domain": "gossip", "type": "rumor_recieved",
                  "attrs": updated_attrs } )
    fired {
      // raise gossip event "schedule_heartbeat"
    }
  }
  
  // This rule needs to send all of this pico's seen messages to the selected peer.
  rule send_seen_message {
    select when gossip send_seen
    pre{
      peer_eci = event:attr("subscriber").klog("Send Seen to: ");
      seen_message = generate_seen_message();
      updated_attrs = event:attrs.put(["message"], seen_message); // adds message to the event:attrs
    }
    event:send( { "eci": peer_eci, "eid": "send-seen-message",
                  "domain": "gossip", "type": "seen_received",
                  "attrs": updated_attrs } )
    fired {
      // raise gossip event "schedule_heartbeat"
    }
  }
  
  // Rule that reacts to another pico sending a rumor message.
  // Essentially, update my logs.
  rule rumor_message_received {
    select when gossip rumor_recieved
    pre {}
    //action:
    send_directive("Pico: " + meta:picoId + " got a Rumor!")
    fired {
      
    }
    else {
      
    }
  }
  
  // Rule that reacts to another pico sending a seen message.
  // Essentially, update my seen messages to match the info I have just recieved from originator.
  rule seen_message_received {
    select when gossip seen_received
    pre {}
    //action:
    send_directive("Pico: " + meta:picoId + " got a Seen!")
    fired {
      
    }
    else {
      
    }
  }
  
}


