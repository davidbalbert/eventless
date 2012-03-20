require 'eventless/version'
require 'eventless/fiber'
require 'eventless/socket'
require 'eventless/loop'
require 'eventless/resolver'
require 'eventless/addrinfo'
require 'eventless/select'
require 'eventless/timeout'
require 'eventless/event'

module Kernel
  alias_method :sleep_block, :sleep

  def sleep(duration)
    Eventless.loop.sleep(duration)
  end
end

module Eventless
  def self.spawn(&block)
    f = Fiber.new(Eventless.loop.fiber, &block)
    Eventless.loop.schedule(f)

    f
  end

  def self.loop
    Loop.default
  end

  def self.resolver
    Loop.default.resolver
  end

  def self.thread_patched?
    false
  end
end
