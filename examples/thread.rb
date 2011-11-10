#!/usr/bin/env ruby

require 'bundler/setup'
require 'eventless'

th = Thread.new("hello", "world") do |a, b|
  puts a + ", " + b
end

th.join
