require 'fiber'

module Eventless
  class Fiber < ::Fiber
    attr_reader :result, :exception
    def initialize(parent=Fiber.current, &block)
      @parent = parent if parent
      @links = []
      @exception = @result = nil

      # It seems without (), super passes all the args that we're
      # called with
      super() do
        begin
          @result = block.call
        rescue StandardError => e
          @exception = e
          print_exception
        end

        Eventless.loop.timer(0) do
          @links.each { |obj, method| obj.send(method, self) }
        end

        @dead = true
        @parent.transfer if @parent
      end
    end

    def print_exception
      puts "#{@exception.class}: #{@exception.message}", @exception.backtrace
    end

    def transfer(*args)
      raise FiberError, "dead fiber called" if @dead
      super(*args)
    end

    def alive?
      return false if @dead
      super
    end

    def dead?
      not alive?
    end

    def success?
      @exception.nil?
    end

    def join
      return if dead?

      # XXX: Will need to implement unlink to handle exceptions
      current = Fiber.current
      link(Fiber.current, :transfer)
      Eventless.loop.transfer
    end

    def link(obj, method)
      @links << [obj, method]
      # XXX: should make this check if the fiber is already dead and then
      # schedule immediately
    end

    def unlink(obj, method)
      @links.remove([obj, method])
    end
  end
end
