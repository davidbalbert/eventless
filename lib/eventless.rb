require 'eventless/version'
require 'eventless/fiber'
require 'eventless/loop'
require 'eventless/socket'

module Kernel
  def sleep(duration)
    fiber = Fiber.current
    Eventless.loop.timer(duration) { fiber.transfer }
    Eventless.loop.transfer
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
