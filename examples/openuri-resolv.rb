#!/usr/bin/env ruby

require 'bundler/setup'
require 'eventless'

require 'open-uri'

Eventless.spawn do
  open("http://www.google.com/") do |f|
    puts f.read
  end
end.join
