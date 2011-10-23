require 'socket'
require 'fcntl'

class BasicSocket < IO
  ##############
  # Sending data
  alias_method :write_block, :write
  def write(*args)
    STDERR.puts "write"
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      result = write_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitWritable, Errno::EINTR
      fcntl(Fcntl::F_SETFL, flags)
      wait(Eventless.loop.io(:write, self))
      retry
    end

    result
  end

  ################
  # Receiving data
  alias_method :recv_block, :recv
  def recv(*args)
    STDERR.puts "recv"
    mesg = ""
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      mesg << recv_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitReadable
      fcntl(Fcntl::F_SETFL, flags)
      STDERR.puts "recv: about to select: #{Socket.unpack_sockaddr_in(getpeername)}"
      wait(Eventless.loop.io(:read, self))
      retry
    end

    mesg
  end

  private
  # XXX: eventually this may have a second command called timeout
  def wait(watcher)
    Eventless.loop.attach(watcher)
    begin
      Eventless.loop.transfer
    ensure
      watcher.detach
    end
  end
end

class Socket < BasicSocket
  alias_method :connect_block, :connect
  def connect(*args)
    STDERR.puts "connect"
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      connect_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitWritable
      fcntl(Fcntl::F_SETFL, flags)
      #STDERR.puts "connect: about to sleep"
      wait(Eventless.loop.io(:write, self))
      retry
    rescue Errno::EISCONN
      fcntl(Fcntl::F_SETFL, flags)
    end
    #STDERR.puts "Connected!"
  end
end


# TODO: this is currently returning a Socket. At some point it needs to return
# a TCPSocket for completeness. `TCPSocket.new.is_a? TCPSocket` will return
# false, which isn't pretty to say the least.
class TCPSocket
  class << self
    alias_method :open_block, :open

    def open(remote_host, remote_port, local_host=nil, local_port=nil)
      sock = Socket.new(:INET, :STREAM)
      sock.connect(Socket.pack_sockaddr_in(remote_port, remote_host))

      if local_host && local_port
        sock.bind(Sock.pack_sockaddr_in(local_port, local_host))
      end

      sock
    end

    alias_method :new_block, :new
    def new(*args)
      open(*args)
    end
  end
end

class TCPServer

  class << self
    def new(hostname=nil, port)
      sock = nil
      Addrinfo.foreach(hostname, port, :INET, :STREAM, nil, Socket::AI_PASSIVE) do |ai|
        begin
          sock = Socket.new(ai.afamily, ai.socktype, ai.protocol)
          sock.setsockopt(:SOCKET, :REUSEADDR, true)
          sock.bind(ai)
        rescue
          sock.close
        else
          break
        end
      end

      sock.listen(5)

      sock
    end
  end
end
