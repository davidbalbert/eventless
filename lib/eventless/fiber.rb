require 'fiber'

class Fiber
  attr_reader :result, :exception, :parent

  alias_method :initialize_original, :initialize
  def initialize(parent=Fiber.current, &block)
    @links = []
    @dead = false
    @parent = parent

    initialize_original do
      begin
        # in case someone started us with transfer_and_raise
        raise_after_transfer!

        @result = block.call
      rescue StandardError => e
        @dead = true
        @exception = e
        print_exception
      end

      @watcher = Eventless.loop.timer(0) do
        @links.each { |obj, method| obj.send(method, self) }
      end
      Eventless.loop.attach(@watcher)

      @dead = true
      @parent.transfer if @parent
    end
  end

  def print_exception
    STDERR.puts "#{@exception.class}: #{@exception.message}", @exception.backtrace
  end

  alias_method :transfer_original, :transfer
  def transfer(*args)
    raise FiberError, "dead fiber called" if dead
    transfer_original(*args) # doesn't return until we get transfered back

    raise_after_transfer!
  end

  def transfer_and_raise(exception)
    self[:to_raise] = exception
    transfer
  end

  def raise_after_transfer!
    if Fiber.current[:to_raise]
      ex = Fiber.current[:to_raise]
      ex = ex.call if ex.respond_to? :call # for testing
      Fiber.current[:to_raise] = nil
      raise ex
    end
  end

  alias_method :alive_original?, :alive?
  def alive?
    return false if @dead
    alive_original?
  end

  def dead?
    not alive?
  end

  def success?
    @exception.nil?
  end

  def join(timeout=nil)
    return if dead?

    timeout = Eventless::Timeout.new(timeout).start

    begin
      link(Fiber.current, :transfer)
      Eventless.loop.transfer
    rescue Eventless::Timeout => t
      raise t unless t == timeout
    end

    nil
  end

  def link(obj, method)
    @links << [obj, method]

    if dead? && !@watcher.attached?
      Eventless.loop.attach(@watcher)
    end
  end

  def unlink(obj, method)
    @links.delete([obj, method])
  end

  # Thread methods
  def [](key)
    fiber_vars[key]
  end

  def []=(key, val)
    fiber_vars[key] = val
  end

  def status
    if dead?
      if success?
        false
      else
        nil
      end
    else
      if self == Fiber.current
        "run"
      else
        "sleep"
      end
    end
  end


  private
  def fiber_vars
    @fiber_vars ||= {}
  end

  def dead
    @dead if defined? @dead
  end
end
