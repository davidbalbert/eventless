#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'eventless'

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
