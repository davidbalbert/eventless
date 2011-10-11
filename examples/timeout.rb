#!/usr/bin/env ruby
# Timeout objects are exceptions. If you start them, they'll be raised in the
# current Fiber when they expire. Note that starting a timeout schedules it on
# the event loop, not in a seperate thread. Starting a timeout doesn't put the
# current fiber to sleep either. For timeouts to work properly, you are
# expected to make a blocking call soon afterwards.
#
# expected output:
# about to sleep for 5 seconds
# timed out after 1!
#
# about to sleep for 3 seconds, timeout 5
# woke up. stoping the timeout and sleeping for 8
# I'm awake!

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'eventless'

puts "about to sleep for 5 seconds"
begin
  timeout = Eventless::Timeout.new(1).start
  sleep 5
  puts "I shouldn't get here!" # we'll never get here
rescue Eventless::Timeout
  puts "timed out after 1!"
end

puts

puts "about to sleep for 3 seconds, timeout 5"
begin
  timeout = Eventless::Timeout.new(5).start
  sleep 3
  puts "woke up. stoping the timeout and sleeping for 8"
  timeout.stop
  sleep 8
  puts "I'm awake!"
rescue Eventless::Timeout
  puts "I should never get here"
end
