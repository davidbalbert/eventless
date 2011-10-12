require 'set'

module Eventless
  class Event
    attr_reader :links
    include Linkable

    def initialize
      @flag = false
      @links = Set.new
    end

    def set?
      @flag
    end

    def set!
      @flag = true
      notify_links!
    end

    def clear!
      @flag = false
    end

    def wait(timeout=nil)
      return if set?

      link(Fiber.current, :transfer)
      begin
        Eventless.loop.transfer
      ensure
        unlink(Fiber.current, :transfer)
      end
    end
  end
end
