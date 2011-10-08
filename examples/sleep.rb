#!/usr/bin/env ruby
# This is a simple and contrived example, but it proves that the event loop
# works. Even though 10 fibers are spawned, each which sleeps for two seconds,
# the program will only take two seconds to run because none of the calls to
# sleep block the event loop.
#
# run with time to verify:
# $ time examples/sleep.rb

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'eventless'

fibers = []
10.times do
  fibers << Eventless.spawn { puts 'about to sleep'; sleep 2; puts 'slept' }
end

fibers.each { |f| f.join }
