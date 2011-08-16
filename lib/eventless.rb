#require 'eventless/version'
require 'socket'
require 'fcntl'
require 'fiber'

STDIN.sync = STDOUT.sync = true

class Thread
  def _eventless_loop
    @_eventless_loop ||= Eventless::Loop.new
  end
end

module Eventless

  def self.wait(mode, io)
    fiber = Fiber.current
    Eventless.loop.attach(mode, io) { fiber.resume }
    Fiber.yield
    Eventless.loop.detach(mode, io)
  end

  def self.run
    self.loop.run
  end

  def self.loop
    Loop.default
  end

  class Loop
    attr_reader :running

    def self.default
      Thread.current._eventless_loop
    end

    def initialize
      @read_fds, @write_fds = {}, {}
    end

    def attach(mode, io, &callback)
      case mode
      when :read
        @read_fds[io] = callback
      when :write
        @write_fds[io] = callback
      else raise ArgumentError, "no such mode: #{mode}"
      end
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
      fd_hash.delete(io) { |el| raise ArgumentError, "#{io} is not attached to #{self} for #{mode}" }
    end

    def num_fds_to_read
      (@read_fds.keys + @write_fds.keys).size
    end

    def run
      @running = true
      while @running and num_fds_to_read > 0
        rs, ws = IO.select(@read_fds.keys, @write_fds.keys)
        rs.each do |fd|
          @read_fds[fd].call
        end

        ws.each do |fd|
          @write_fds[fd].call
        end
      end

      @running = false
    end
  end
end

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
  Fiber.new {
    s = Socket.new(:INET, :STREAM)
    sockaddr = Socket.pack_sockaddr_in(80, host)
    s.connect(sockaddr)
    s.write( "GET / HTTP/1.0\r\n\r\n" )
    str = ""
    loop do
      str = s.recv(100000)
      puts str
      break if str == ""
    end
  }.resume
end

eventless_get('www.google.com')
eventless_get('news.ycombinator.com')

Eventless.run
