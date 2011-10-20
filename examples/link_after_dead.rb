#!/usr/bin/env ruby
# If we link a method to a dead fiber, it should be called immediately

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'eventless'

def say_goodbye(fiber)
  puts "goodbye!"
end

f = Eventless.spawn { puts "in the fiber" }
f.join

f.link(self, :say_goodbye)
sleep 0 # yield back to the event loop

