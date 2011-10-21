require 'timeout'

module Eventless
  class Timeout < StandardError
    # if seconds is nil, the timeout will be fake and start and
    # stop will do nothing
    def initialize(seconds)
      @seconds = seconds
      @started = false
    end

    def self.start_new(timeout)
      if timeout.is_a? Timeout
        timeout.start unless timeout.started?
      else
        timeout = new(timeout)
      end

      timeout
    end

    def start
      return self if @seconds.nil?
      raise "timeout already started" if @started

      @started = true
      current = Fiber.current
      @watcher = Eventless.loop.timer(@seconds) do
        current.transfer_and_raise self
      end
      Eventless.loop.attach(@watcher)

      self
    end

    def started?
      @started
    end

    def stop
      return if @seconds.nil?
      raise "timeout has not been started" unless @started

      @started = false
      @watcher.detach if @watcher.attached?
    end
  end
end

module Timeout
  alias_method :timeout_old, :timeout

  def timeout(sec, klass = nil)
    return yield(sec) if sec == nil or sec.zero?
    exception = klass || Error

    timeout = Eventless::Timeout.new(sec).start
    begin
      return yield(sec)
    rescue Eventless::Timeout
      raise exception, "execution expired"
    ensure
      timeout.stop
    end
  end

  module_function :timeout
end

def timeout(n, e = nil, &block)
  Timeout::timeout(n, e, &block)
end
