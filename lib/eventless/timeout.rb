module Eventless
  class Timeout < StandardError
    def initialize(seconds)
      @seconds = seconds
      @started = false
    end

    def start
      raise "timeout already started" if @started

      @started = true
      current = Fiber.current
      @watcher = Eventless.loop.timer(@seconds) do
        current.transfer_and_raise self
      end

      Eventless.loop.attach(@watcher)
      self
    end

    def stop
      raise "timeout has not been started" unless @started

      @started = false
      @watcher.detach
    end
  end
end
