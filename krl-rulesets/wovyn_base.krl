ruleset wovyn_base {
  meta {
    shares __testing
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
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      never_used = event:attrs.klog("attrs")
    }
    send_directive("Wovyn Info", {"info":never_used})
  }
}
