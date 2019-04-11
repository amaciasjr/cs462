ruleset gossip {
  meta {
    shares __testing, sequence_number, my_gossip, get_peers, temp_logs, seen_messages
    
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { 
      "queries":[ 
        { "name": "__testing" },
        { "name": "temp_logs" },
        { "name": "seen_messages" },
        { "name": "my_gossip" },
        { "name": "sequence_number" },
        { "name": "get_peers" }
      //{ "name": "entry", "args": [ "key" ] }
      ] , 
      "events":[ 
        { "domain": "gossip", "type": "new_temp", "attrs": [ "temperature" ]  },
        { "domain": "gossip", "type": "heartbeat"}
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    sequence_number = function() {
      my_gossip().length() - 1
    }
    
    my_gossip = function() {
      ent:gossip_messages => ent:gossip_messages | []
    }
    
    temp_logs = function() {
      ent:temperature_logs => ent:temperature_logs | {}
    }
    
    seen_messages = function() {
      ent:seen_messages => ent:seen_messages | {}
    }
    
    heartbeat_time = function() {
      ent:heartbeat_time => ent:heartbeat_time | 15
    }
    
    rand_int = function(peers) {
      num_of_peers = peers.length().klog("# of Peers: ");
      rand_peer = random:integer(upper = num_of_peers-1, lower = 0);
      rand_peer
    }
    
    generate_rumor_message = function( picoId, temperature, timestamp  ) {
      message_id = picoId + ":" + my_gossip().length().as("String").klog("Gen. Rum. Gossip Size: ");
      gossip_message = {
        "MessageID": message_id,
        "SensorID": picoId,
        "Temperature": temperature,
        "Timestamp": timestamp
      };
      gossip_message
    }
    
    // Get specific rumor message(s) that a given peer needs.
    find_rumor_messages = function(peer_eci) {
      my_messages = my_gossip();
      exists = seen_messages().filter(function(v,k){k == peer_eci}).klog("EXISTS IN FIND RUMOR: ");
      rumor_to_send = ((exists == {}).klog("TRUE/FALSE: ") => my_messages[0] | compare_seen(peer_eci, exists).klog("What is exists: ") ).klog("RUMOR BEING SENT: ");
      rumor_to_send
    }
    
    compare_seen = function(peer, seen_messages) {
      
    }
    
    verify_originator = function(picoId) {
      temp_logs().filter(function(v,k){k == picoId})
    }
    
    // get_peers() needs to return a "subscription eci" associated with the peer's PicoID
    get_peers = function() {
      // my_messages = get_my_gossip().klog("Current State: ");
      subscription:established().map(function(v,k) {
        subscription_Tx = v{"Tx"};
        subscription_Tx
      });
      
    }

  }
  
  // This rule listens for new temperature readings,
  // then generate new log to added to your 
  rule new_temp_recieved {
    select when gossip new_temp
    pre {
      pico_id_map = {}
      my_pico_id     = meta:picoId.klog("Pico ID: ");
      temp_received  = (event:attr("temperature") => event:attr("temperature") | null).klog("Received Temp: "); 
      time_received  = time:now().klog("Time Received: "); 
      rumor_message  = generate_rumor_message(my_pico_id, temp_received, time_received);
      
    }
    // Check if rumor_message was created.
    if rumor_message
      then noop()
    
    fired {
      pico_id_map{my_pico_id} = my_gossip().length().klog("Gossip Size-1: ");
      ent:gossip_messages := my_gossip().append(rumor_message);
      ent:temperature_logs{my_pico_id} := ent:gossip_messages;
      ent:seen_messages{my_pico_id} := pico_id_map;
      // ent:message_number := sequence_number() + 1;
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
      rand_message = 0//random:integer(1)
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
      rumor_message = find_rumor_messages(peer_eci).klog("Rumor: ");
      updated_attrs = event:attrs.put(["rumor_message"], rumor_message); // adds message to the event:attrs
      
    }
    event:send( { "eci": peer_eci, "eid": "send-rumor-message",
                  "domain": "gossip", "type": "rumor_recieved",
                  "attrs": updated_attrs } )
    fired {
      // ent:seen_messages{peer_eci} := rumor_message{"MessageID"}
      // raise gossip event "schedule_heartbeat"
      //   attributes updated_attrs;
      
    }
  }
  
  // Rule that reacts to another pico sending a rumor message.
  // Essentially, update my logs.
  rule rumor_message_received {
    select when gossip rumor_recieved
    pre {
      rumor_recieved = event:attr("rumor_message").klog("Rumor Received: ");
      message_originator = rumor_recieved{"SensorID"}
      exists = verify_originator(message_originator)
      temp = []
      // message_exists = verify_message(rumor_recieved{"MessageID"})
    }
    if (exists != {} ) then
    send_directive("Pico: " + meta:picoId + " got a Rumor message: " + rumor_recieved)
    fired {
      ent:temperature_logs{message_originator} := ent:temperature_logs{message_originator}.append(rumor_recieved);
    } else {
      ent:temperature_logs{message_originator} := temp.append(rumor_recieved);
    }
  }
  
  // This rule needs to send all of this pico's seen messages to the selected peer.
  rule send_seen_message {
    select when gossip send_seen
    pre{
      peer_eci = event:attr("subscriber").klog("Send Seen to: ");
      updated_attrs = event:attrs.put(["seen_messages"], temp_logs()).klog("Send_seen UPDATED ATTRS: ");
      
    }
    event:send( { "eci": peer_eci, "eid": "send-seen-message",
                  "domain": "gossip", "type": "seen_received",
                  "attrs": updated_attrs } )
    fired {
      // raise gossip event "schedule_heartbeat"
    }
  }
  
  // Rule that reacts to another pico sending a seen message.
  // Essentially, update my seen messages to match the info I have just recieved from originator.
  rule seen_message_received {
    select when gossip seen_received
    foreach event:attr("seen_messages").defaultsTo({}) setting (messageArray,picoId)
    pre {
      pId_messageSize_map = {}
      array = messageArray.klog("REC seen array: ");
      ID =  picoId.klog("REC seen ID: ")
      pId_messageSize_map{picoId} =  messageArray.length() - 1;
    }
    //action:
    if event:attr("seen_messages") == {}
      then noop()
    fired {
      // May use this later to propagate messages faster. 
    }
    else{
      ent:seen_messages{picoId} := pId_messageSize_map;
    }
  }
  
}

