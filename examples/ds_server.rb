# Use in conjunction with ds_client.rb for testing puts/putc/gets/getc

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'socket'
require 'eventless'

server = TCPServer.new 2000

loop {
  while client = server.accept
      client.puts "One"
      client.puts "Hello!"
      client.puts "Nice to see you!\n"
      client.puts "Today would be improved by snails, don't you think?"
      client.putc "Two"

      tests = %w(three four five six seven eight nine ten).map do |word|
        Eventless.spawn { sleep Random.rand(6); client.puts word }
      end

      tests.each { |t| t.join }

      client.close
  end
}