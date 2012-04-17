# NOTE: This is a proof of concept for how we might monkeypatch Thread to spawn
# new fibers instead of new threads. It doesn't currently work with
# Eventless::ThreadPool, which is required for DNS resolution, therefore it is
# disabled. It's also very hacky and untested. Maybe some day...
raise "eventless/thread is not supported right now. Sorry!"

require 'thread'

module Eventless
  class << self
    undef thread_patched?
    def thread_patched?
      true
    end
  end
end

class Thread
  class << self
    # XXX: doing this won't work for subclasses of Thread (I think)
    undef new
    def new(*args, &block)
      f = Fiber.new(Eventless.loop.fiber, &block)
      f.is_thread = true
      Eventless.loop.schedule(f, *args)

      f
    end

    undef start
    undef fork
    alias_method :start, :new
    alias_method :fork, :new

    alias_method :_thread_pass, :pass
    def pass
      Eventless.sleep(0)
    end

    alias_method :_thread_current, :current
    def current
      Fiber.current
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
        @owner[:mutexes] ||= []
        @owner[:mutexes] << self
        true
      end
    end

    def lock
      unless try_lock
        if @owner == Fiber.current
          raise ThreadError, "deadlock; recursive locking"
        end

        @waiters << Fiber.current
        Eventless.loop.transfer
      end

      self
    end

    def unlock
      if @owner != Fiber.current
        raise ThreadError, "Not owner of the lock, #{@owner.inspect} is. Can't release"
      end

      @owner[:mutexes].delete(self)

      @owner = @waiters.shift
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

Object.send(:remove_const, :Mutex)
Mutex = Eventless::Mutex
