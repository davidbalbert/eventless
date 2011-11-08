require 'thread'

class Thread
  class << self
    # doing this won't work for subclasses of Thread (I think).
    def new(*args, &block)
      f = Fiber.new(*args, &block)
      Eventless.loop.schedule(f)

      f
    end

    alias_method :start, :new
    alias_method :fork, :new

    def pass
      Eventless.sleep(0)
    end
  end
end

module Eventless
  class Mutex
    def initialize
      @owner = nil
      @waiters = []
    end

    def locked?
      not @owner.nil?
    end

    def try_lock
      if locked?
        false
      else
        @owner = Fiber.current
        true
      end
    end

    def lock
      unless try_lock
        if @owner == Fiber.current
          raise ThreadError, "deadlock; recursive locking"
        end

        f = Fiber.current
        f.sleeping = true
        @waiters << f
        Eventless.loop.transfer
      end

      self
    end

    def unlock
      if @owner != Fiber.current
        raise ThreadError, "Not owner of the lock, #{@owner.inspect} is. Can't release"
      end

      @owner = @waiters.shift
      @owner.sleeping = false unless @owner.nil?
      Eventless.loop.schedule(@owner) if @owner

      self
    end

    # XXX: Rubinius doesn't implement this yet, so I'm going to skip it for now
    def sleep(timeout = nil)
      raise "Whoops, Eventless doesn't implement Mutex#sleep yet"
    end

    def synchronize
      lock
      begin
        yield
      ensure
        unlock
      end
    end
  end
end

Mutex = Eventless::Mutex
