#!/usr/bin/env ruby

require 'bundler/setup'

require 'eventless'

puts IPSocket.getaddress("www.google.com")
