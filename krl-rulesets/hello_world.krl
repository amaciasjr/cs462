ruleset hello_world {
  meta {
    name "Hello World"
    description <<
This ruleset was used to complete Lab 1.
>>
    author "Art Macias"
    logging on
    shares hello, __testing
  }
  
  global {
    hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }

    __testing = { "queries": [ { "name": "hello", "args": [ "obj" ] },
                           { "name": "__testing" } ],
                  "events": [ { "domain": "echo", "type": "hello",
                            "attrs": [ "name" ] } ]
                }
  }
  
  rule hello_world {
    select when echo hello
    send_directive("say", {"something": "Hello World"})
  }

  rule hello_monkey {
    select when echo monkey
    pre {
      name = event:attr("name").defaultsTo("Monkey").klog("*** The passed in name: ***")
    }	
    send_directive("say", {"something":"Hello " + name})
  }

  rule hello_monkey_ternary {
    select when echo monkey_ternary
    pre {
      name = ( ( event:attr("name").isnull() ) =>  "Monkey" | event:attr("name") ).klog("*** The passed in name: ***")
    }	
    send_directive("say", {"something":"Hello " + name})
  }
} 
