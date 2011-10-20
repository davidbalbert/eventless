#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'eventless'

# XXX: this behavior might become a bug
# I'm not really sure
event = Eventless::Event.new
f = Eventless.spawn { event.wait }
begin
  f.join
rescue
  puts "#{$!.class}: #{$!.message}", $@
end


event = Eventless::Event.new

waiters = []
5.times do |i|
  waiters << Eventless.spawn do
    puts "#{i} waiting"
    event.wait
    puts "I am number #{i} and I'm awake!"
  end
end

sleep 0.1 # let the waiters all start waiting
event.set!

waiters.each { |waiter| waiter.join }
