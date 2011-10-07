#require 'eventless/version'
require 'socket'
require 'fcntl'
require 'fiber'

require 'cool.io'

STDIN.sync = STDOUT.sync = true

class Thread
  def _eventless_loop
    @_eventless_loop ||= Eventless::Loop.new
  end
end

module Kernel
  def sleep(duration)
    fiber = Fiber.current
    Eventless.loop.timer(duration) { fiber.transfer }
    Eventless.loop.transfer
  end
end

module Eventless

  def self.spawn(&callback)
    f = Fiber.new(Eventless.loop.fiber, &callback)
    Eventless.loop.schedule(f)

    f
  end

  # XXX: Probably want to change the name of this or make it private
  # Eventless.wait might be confused with Eventless.join
  def self.wait(mode, io)
    fiber = Fiber.current
    Eventless.loop.attach(mode, io) { fiber.transfer }
    Eventless.loop.transfer
    Eventless.loop.detach(mode, io)
  end

  def self.loop
    Loop.default
  end

  class Fiber < Fiber
    def initialize(parent=Fiber.current, &block)
      @parent = parent if parent
      @links = []

      super() do
        block.call

        Eventless.loop.timer(0) do
          @links.each { |callback| callback.call }
        end

        @dead = true
        @parent.transfer if @parent
      end
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

    def join
      return if dead?

      # XXX: Will need to implement unlink to handle exceptions
      current = Fiber.current
      link { current.transfer }
      Eventless.loop.transfer
    end

    def link(&callback)
      @links << callback
    end

  end

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

    def schedule(fiber)
      # XXX: kind of hacky
      # non-repeating timeout of 0
      timer(0) { fiber.transfer }
    end

    def timer(duration, &callback)
      watcher = Coolio::TimerWatcher.new(duration)
      watcher.on_timer do
        watcher.detach
        callback.call
      end

      watcher.attach(@loop)
    end

    def attach(mode, io, &callback)
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

    def detach(mode, io)
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

# class IO
  # alias_method :write_block, :write

  # # XXX: NOT WORKING!!!!
  # def write(*args)
    # begin
      # flags = fcntl(Fcntl::F_GETFL, 0)
      # result = write_nonblock(*args)
      # fcntl(Fcntl::F_SETFL, flags)
    # rescue IO::WaitWritable, Errno::EINTR
      # fcntl(Fcntl::F_SETFL, flags)
      # STDERR.puts "write: about to select"
      # Eventless.wait(:write, self)
      # retry
    # end
    # STDERR.puts "done writing"
    # result
  # end
# end

class BasicSocket < IO
  alias_method :recv_block, :recv

  def recv(*args)
    mesg = ""
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      mesg << recv_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitReadable
      fcntl(Fcntl::F_SETFL, flags)
      STDERR.puts "recv: about to select: #{Socket.unpack_sockaddr_in(getpeername)}"
      Eventless.wait(:read, self)
      retry
    end
    mesg
  end
end

class Socket < BasicSocket
  alias_method :connect_block, :connect

  def connect(*args)
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      connect_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitWritable
      fcntl(Fcntl::F_SETFL, flags)
      STDERR.puts "connect: about to sleep"
      Eventless.wait(:write, self)
      retry
    rescue Errno::EISCONN
      fcntl(Fcntl::F_SETFL, flags)
    end
    STDERR.puts "Connected!"
  end
end

#serv = TCPServer.new("127.0.0.1", 12345)
#af, port, host, addr = serv.addr
#s = serv.accept
#puts s.recv(10)


def eventless_get(host)
  s = Socket.new(:INET, :STREAM)
  sockaddr = Socket.pack_sockaddr_in(80, host)
  s.connect(sockaddr)
  s.write( "GET / HTTP/1.0\r\n\r\n" )
  site = ""
  loop do
    str = s.recv(100000)
    site << str
    # puts str
    break if str == ""
  end

  STDERR.puts "#{host}: #{site.size}"
  puts site
end

#jobs = %w(www.google.com news.ycombinator.com).map do |url|
# jobs = %w(dave.is www.nick.is).map do |url|
  # Eventless.spawn { eventless_get(url) }
# end

# STDERR.puts jobs

fibers = []
5.times do
  fibers << Eventless.spawn { puts 'about to sleep'; sleep 2; puts 'slept' }
end

fibers.each do |f|
  f.join;
end

Eventless.spawn { puts 'about to sleep'; sleep 2; puts 'slept' }.join
Eventless.spawn { puts 'about to sleep'; sleep 2; puts 'slept' }.join
