require 'eventless/version'
require 'eventless/fiber'
require 'eventless/loop'
require 'eventless/socket'
require 'eventless/select'
require 'eventless/timeout'
require 'eventless/event'
require 'eventless/thread'

module Kernel
  alias_method :sleep_block, :sleep

  def sleep(duration)
    Eventless.loop.sleep(duration)
  end
end

module Eventless
  def self.spawn(&callback)
    f = Fiber.new(Eventless.loop.fiber, &callback)
    Eventless.loop.schedule(f)

    f
  end

  def self.loop
    Loop.default
  end
end
