#!/usr/bin/env ruby

require 'bundler/setup'
require 'eventless'
require 'eventless/thread'

m = Mutex.new

scratch_pad = []

m.lock

th = Thread.new do
  puts "locking"
  m.lock
  scratch_pad << :after_lock
end

puts "status: #{th.status}"
Thread.pass while th.status and th.status != "sleep"

puts "Should be empty: #{scratch_pad.inspect}"
puts "unlocking"
m.unlock
th.join
puts "Should be have :after_lock: #{scratch_pad.inspect}"
