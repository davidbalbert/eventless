#!/usr/bin/env ruby


$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
#$:.unshift File.join(File.dirname(__FILE__), "..", "..", 'ruby', 'lib')
#$:.unshift File.join(File.dirname(__FILE__), "..", "..", 'ruby', 'ext', 'socket', 'lib')

require 'rack'
require 'eventless'
require 'eventless/thread'

#require 'kgb'

#KGB.spy_on(Socket, TCPSocket, TCPServer)

Rack::Server.start(
  :app => lambda do |e|
    [200, {'Content-Type' => 'text/html'}, ['hello world']]
  end,
  :Port => 3000,
)
