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
      @read_fds, @write_fds = {}, {}
      @loop = Coolio::Loop.new
      @fiber = Fiber.new { run }
    end

    def transfer(*args)
      @fiber.transfer(*args)
    end

    def io(mode, io)
      fiber = Fiber.current
      io_attach(mode, io) { fiber.transfer }
      begin
        transfer
      ensure
        io_detach(mode, io)
      end
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

    def io_attach(mode, io, &callback)
      watcher = Coolio::IOWatcher.new(io, if mode == :read then 'r' else 'w' end)
      case mode
      when :read
        watcher.on_readable &callback
        @read_fds[io] = watcher
      when :write
        watcher.on_writable &callback
        @write_fds[io] = watcher
      else raise ArgumentError, "no such mode: #{mode}"
      end

      watcher.attach(@loop)
    end

    def io_detach(mode, io)
      fd_hash = nil
      case mode
      when :read
        fd_hash = @read_fds
      when :write
        fd_hash = @write_fds
      else raise ArgumentError, "no such mode: #{mode}"
      end
      watcher = fd_hash.delete(io) { |el| raise ArgumentError, "#{io} is not attached to #{self} for #{mode}" }
      watcher.detach
    end

    private
    def run
      @loop.run
    end
  end
end
