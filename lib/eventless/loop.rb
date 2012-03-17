require 'eventless/core_ext/silence_warnings'
require 'eventless/resolver'

require 'thread'

silence_warnings do
  require 'cool.io'
end

class Thread
  def _eventless_loop
    @_eventless_loop ||= Eventless::Loop.new
  end
end

module Eventless
  class Loop
    attr_reader :running, :fiber, :resolver

    def self.default
      unless Eventless.thread_patched?
        Thread.current._eventless_loop
      else
        Thread._thread_current._eventless_loop
      end
    end

    def initialize
      @loop = Coolio::Loop.new
      @fiber = Fiber.new(Fiber.current) { run }

      setup_resolver
    end

    def transfer(*args)
      raise "You can't call a blocking function from the event loop" if Fiber.current == self

      @fiber.transfer(*args)
    end

    def io(mode, io, &callback)
      fiber = Fiber.current
      callback = proc { fiber.transfer } unless callback

      watcher = Coolio::IOWatcher.new(io, if mode == :read then 'r' else 'w' end)
      case mode
      when :read
        watcher.on_readable(&callback)
      when :write
        watcher.on_writable(&callback)
      else raise ArgumentError, "no such mode: #{mode}"
      end

      watcher
    end

    def timer(duration, repeating=false, &callback)
      watcher = Coolio::TimerWatcher.new(duration, repeating)
      watcher.on_timer do
        watcher.detach unless repeating
        callback.call
      end

      watcher
    end

    def sleep(duration)
      fiber = Fiber.current
      watcher = timer(duration) { fiber.transfer }

      watcher.attach(@loop)
      begin
        transfer
      ensure
        watcher.detach if watcher.attached?
      end

      # if we return, then we've slept the full amount of time, so just return
      # what we said we were going to sleep. The only way for us to stop
      # sleeping early is if there's a Timeout, which is an exception, so we'll
      # never return from Loop#wait above.
      duration.round
    end

    def schedule(fiber, *args)
      # XXX: kind of hacky
      # non-repeating timeout of 0
      watcher = timer(0) { fiber.transfer(*args) }
      watcher.attach(@loop)
    end

    def attach(watcher)
      watcher.attach(@loop)
    end

    def detach(watcher)
      watcher.detach
    end

    private
    def run
      loop do
        @loop.run
        @fiber.parent.transfer_and_raise "This code would block forever!"
      end
    end
  end
end
