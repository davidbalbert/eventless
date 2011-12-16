#!/usr/bin/env ruby

require 'bundler/setup'

require 'eventless'

puts IPSocket.getaddress("www.google.com")

p Socket.unpack_sockaddr_in(Socket.pack_sockaddr_in(80, "www.google.com"))

p Socket.pack_sockaddr_in(80, "www.google.com")
