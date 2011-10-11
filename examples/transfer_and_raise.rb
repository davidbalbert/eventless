#!/usr/bin/env ruby
# Expected output:
# root fiber: #<Fiber:0x007fae9292eff8>
# RuntimeError: Exception in fiber: #<Fiber:0x007fae9292ef30>
# /Users/david/Development/eventless/lib/eventless/fiber.rb:55:in `raise_after_transfer!'
# /Users/david/Development/eventless/lib/eventless/fiber.rb:15:in `block in initialize'
#
# before transfering to root
# you saved me!

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'eventless'

# raise an exception immediately. This will be caught by the fiber and the
# stack trace will be printed, but the event loop will continue. We can't catch
# the exception ourselves because it gets raised before our block gets called
root = Fiber.current
puts "root fiber: #{root.inspect}"
f = Fiber.new do
  puts "I shouldn't get here"
end

f.transfer_and_raise lambda { "Exception in fiber: #{Fiber.current.inspect}" }

puts

# start the fiber, return control to the root fiber and then raise an
# exception. Because root.transfer is inside a begin/rescue, we can catch the
# exception.
f2 = Fiber.new do
  begin
    puts "before transfering to root"
    root.transfer
    puts "I shouldn't get here either"
  rescue
    puts "you saved me!"
  end
end

f2.transfer
f2.transfer_and_raise lambda { "Exception in fiber: #{Fiber.current.inspect}" }
