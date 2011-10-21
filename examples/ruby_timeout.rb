#!/usr/bin/env ruby
#
# test of the monkeypatched timeout.rb library
#

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'eventless'

Timeout.timeout(1) {
  puts "sleeping for 5, will timeout after 1"
  sleep 5
}
