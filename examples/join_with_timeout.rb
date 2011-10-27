#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'eventless'

f = Eventless.spawn do
  puts "I'll sleep for 5 but timeout in 1"
  sleep 5
  puts "I shouldn't get here"
end

f.join(1)
puts "I'm done"
