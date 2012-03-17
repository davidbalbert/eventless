# Use in conjunction with ds_server.rb for testing puts/putc/gets/getc
# Expected output is:
# OH
# Nice to see you!
# Today would be improved by snails, don't you think?
# T

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'socket'
require 'eventless'

host = 'localhost'
port = 2000

s = TCPSocket.new host, port

2.times { putc s.gets }

while line = s.gets
  break if line == ""
  puts line
end

s.close