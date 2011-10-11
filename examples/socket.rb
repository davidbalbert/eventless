#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'eventless'


# none of this works. it's just scratch space

#serv = TCPServer.new("127.0.0.1", 12345)
#af, port, host, addr = serv.addr
#s = serv.accept
#puts s.recv(10)


def eventless_get(host)
  s = Socket.new(:INET, :STREAM)
  sockaddr = Socket.pack_sockaddr_in(80, host)
  s.connect(sockaddr)
  s.write( "GET / HTTP/1.0\r\n\r\n" )
  site = ""
  loop do
    str = s.recv(100000)
    site << str
    # puts str
    break if str == ""
  end

  STDERR.puts "#{host}: #{site.size}"
  puts site
end

#jobs = %w(www.google.com news.ycombinator.com).map do |url|
#jobs = %w(dave.is www.nick.is).map do |url|

# get a whole bunch of google's ips at the same time. Domain name resolution
# blocks so we're using ip addresses for now
jobs = %w(74.125.226.240 74.125.226.241 74.125.226.242 74.125.226.243 74.125.226.244).map do |url|
  Eventless.spawn { eventless_get(url) }
end

jobs.each { |j| j.join }

STDERR.puts jobs
