#!/usr/bin/env ruby

require 'bundler/setup'

require 'eventless'
classes = [
           Eventless::BasicSocket,
           Eventless::Socket,
           Eventless::IPSocket,
           Eventless::TCPSocket,
           Eventless::TCPServer,
           Eventless::UDPSocket
          ]

class Object
  def self.all_methods
    methods(false).map { |m| "::#{m}" }.sort + instance_methods(false).map { |m| "##{m}" }.sort
  end
end

total_implemented = total_methods = 0

classes.each do |c|
  stock_methods = Eventless.const_get("Real#{c.name.split('::').last}").all_methods
  eventless_methods = c.all_methods

  # XXX: Add IO methods to the methods to implement for BasicSocket
  # because Eventless::BasicSocket needs to provide the same interface
  # as the stock BasicSocket even though it does not inherit from IO
  if c == Eventless::BasicSocket
    stock_methods = (stock_methods + IO.all_methods).uniq
    stock_methods = stock_methods.select { |m| m.match(/^::/) }.sort +
                    stock_methods.select { |m| m.match(/^#/) }.sort
  end

  not_implemented = stock_methods - eventless_methods
  implemented = stock_methods - not_implemented

  total_methods += stock_methods.count
  total_implemented += implemented.count

  pct_complete = (implemented.count.to_f / stock_methods.count) * 100
  pct_complete = pct_complete % 1 == 0 ? pct_complete.to_i : pct_complete.round(2)

  puts "#{c} is #{pct_complete}% complete [#{implemented.count}/#{stock_methods.count}]"
  if ARGV.length > 0 and ARGV[0] == '-v'
    puts "    Implemented" unless implemented.empty?
    implemented.each do |method|
      puts "      #{method}"
    end

    puts "    Unimplemented" unless not_implemented.empty?
    not_implemented.each do |method|
      puts "      #{method}"
    end
  end
end

pct_complete = (total_implemented.to_f / total_methods) * 100
pct_complete = pct_complete % 1 == 0 ? pct_complete.to_i : pct_complete.round(2)

puts
puts "Total is #{pct_complete}% complete [#{total_implemented}/#{total_methods}]"
