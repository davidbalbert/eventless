require 'set'

module Eventless
  class Event
    def initialize
      @flag = false
      @links = Set.new
      @todo = Set.new

      @watcher = Eventless.loop.timer(0) do
        todo_array = @todo.to_a
        while todo_array.size > 0
          link = todo_array.pop
          if @links.include?(link)
            obj, msg = link
            obj.send(msg, self)
          end
        end

        @todo.clear
      end
    end

    def set?
      @flag
    end

    def set!
      @flag = true
      @todo = @todo + @links
      if @todo.size > 0 && !@watcher.attached?
        Eventless.loop.attach(@watcher)
      end
    end

    def clear!
      @flag = false
    end

    def wait(timeout=nil)
      return true if set?

      link(Fiber.current, :transfer)
      begin
        Eventless.loop.transfer
      ensure
        unlink(Fiber.current, :transfer)
      end

      @flag
    end

    def link(obj, method)
      @links << [obj, method]

      if @flag && !@watcher.attached?
        @todo << [obj, method]
        Eventless.loop.attach(@watcher)
      end
    end

    def unlink(obj, method)
      @links.delete([obj, method])
    end
  end
end
