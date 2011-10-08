#!/usr/bin/env ruby
# Demonstrates how exceptions are handled. The first fiber raises an uncaught
# exception, but it doesn't crash the event loop. Notice that `f2` successfully
# prints "after exception" even though `f1` raised an error.
#
# Expected output:
#
# $ examples/exception.rb
# before exception
# RuntimeError: Hello, exception!
# [prints backtrace]
# after exception


$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'eventless'

f1 = Eventless.spawn { puts 'before exception'; raise "Hello, exception!" }
f2 = Eventless.spawn { puts 'after exception' }

f1.join
f2.join
