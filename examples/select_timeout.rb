#!/usr/bin/env ruby
#
# Don't connect to this server. It will timeout after 1 seconds
#
# Expected output:
# I timed out!

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'socket'

require 'eventless'

acceptor = Socket.new(:INET, :STREAM)
address = Socket.pack_sockaddr_in(1337, '127.0.0.1')
acceptor.bind(address)
acceptor.listen(10)

if IO.select([acceptor], nil, nil, 1)
  socket, addr = acceptor.accept
  # do stuff with the socket
  socket.close
else
  puts "I timed out!"
end

acceptor.close
