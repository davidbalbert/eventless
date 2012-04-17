#!/usr/bin/env ruby

require 'bundler/setup'

require 'eventless'

fibers = []
%w(www.google.com ipv6.google.com www.yahoo.com www.bing.com).each do |host|
  fibers << Eventless.spawn do
    p Addrinfo.getaddrinfo(host, 80)
  end
end

fibers.each { |f| f.join }
