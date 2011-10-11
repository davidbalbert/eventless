#!/usr/bin/env ruby
# Expected output:
# f1
# f.success? = true
# f.result = foo
#
# f2
# RuntimeError: Hi there
# examples/fiber_return_values.rb:14:in `block in <main>'
# /Users/david/Development/eventless/lib/eventless/fiber.rb:16:in `call'
# /Users/david/Development/eventless/lib/eventless/fiber.rb:16:in `block in initialize'
# f2.success? = false
# f2.exception = Hi there

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'eventless'

puts "f1"
f = Eventless.spawn { "foo" }
f.join
puts "f.success? = #{f.success?}"
puts "f.result = #{f.result}"

puts "\nf2"
f2 = Eventless.spawn { raise "Hi there" }
f2.join
puts "f2.success? = #{f2.success?}"
puts "f2.exception = #{f2.exception}"
