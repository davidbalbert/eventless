require 'cool.io'

class Thread
  def _eventless_loop
    @_eventless_loop ||= Eventless::Loop.new
  end
end

module Eventless
  class Loop
    attr_reader :running, :fiber

    def self.default
      Thread.current._eventless_loop
    end

    def initialize
      @loop = Coolio::Loop.new
      @fiber = Fiber.new(Fiber.current) { run }
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
        watcher.on_readable &callback
      when :write
        watcher.on_writable &callback
      else raise ArgumentError, "no such mode: #{mode}"
      end

      watcher
    end

    def timer(duration, &callback)
      watcher = Coolio::TimerWatcher.new(duration)
      watcher.on_timer do
        watcher.detach
        callback.call
      end

      watcher
    end

    def sleep(duration)
      fiber = Fiber.current
      watcher = timer(duration) { fiber.transfer }
      wait(watcher)

      # if we return, then we've slept the full amount of time, so just return
      # what we said we were going to sleep. The only way for us to stop
      # sleeping early is if there's a Timeout, which is an exception, so we'll
      # never return from Loop#wait above.
      duration.round
    end

    def schedule(fiber)
      # XXX: kind of hacky
      # non-repeating timeout of 0
      watcher = timer(0) { fiber.transfer }
      watcher.attach(@loop)
    end

    def wait(watcher)
      watcher.attach(@loop)
      begin
        transfer
      ensure
        watcher.detach if watcher.attached?
      end
    end

    def attach(watcher)
      watcher.attach(@loop)
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
