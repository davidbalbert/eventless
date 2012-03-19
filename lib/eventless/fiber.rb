require 'fiber'

class Fiber
  attr_accessor :parent, :is_thread
  attr_reader :result, :exception

  alias_method :initialize_original, :initialize
  def initialize(parent=Fiber.current, &block)
    @links = []
    @dead = false
    @parent = parent
    @is_thread = false
    @started = false

    initialize_original do |*args|
      begin
        @started = true

        # in case someone started us with transfer_and_raise
        raise_after_transfer!

        @result = block.call(*args)
      rescue StandardError => e
        raise e if @is_thread
        @dead = true
        @exception = e
        print_exception
      rescue FiberExit => e
        @dead = true
        @exception = e
      end

      # When Threads terminate, they unlock any mutexes that they are currently
      # holding
      #
      # Mutex#unlock removes self from @owner[:mutexes], so we must
      # clone self[:mutexes] before iterating.
      if self[:mutexes]
        mutexes_clone = self[:mutexes].clone
        mutexes_clone.each do |m|
          m.unlock
        end
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

  def transfer_and_raise(exception, msg=nil)
    raise_later(exception, msg)
    transfer
  end

  def raise_later(exception, msg=nil)
    exception = [exception, msg] unless msg.nil?
    self[:to_raise] = exception
  end

  def raise_after_transfer!
    if Fiber.current[:to_raise]
      ex = Fiber.current[:to_raise]
      msg = nil
      if ex.kind_of? Array
        ex, msg = ex
      end

      # for testing: allow a proc that returns an exception
      ex = ex.call if ex.respond_to? :call

      Fiber.current[:to_raise] = nil
      raise ex, msg
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
      return nil
    end

    self
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
      if self == Fiber.current or is_new_thread?
        "run"
      else
        "sleep"
      end
    end
  end

  def exit
    if self == Fiber.current
      raise FiberExit
    else
      raise_later FiberExit
    end
  end
  alias_method :kill, :exit
  alias_method :terminate, :exit

  private
  def fiber_vars
    @fiber_vars ||= {}
  end

  def dead
    @dead if defined? @dead
  end

  def is_new_thread?
    @is_thread and not @started
  end
end

class FiberExit < Exception; end
