require 'socket'
require 'fcntl'

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
      Eventless.loop.io(:read, self)
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
      Eventless.loop.io(:write, self)
      retry
    rescue Errno::EISCONN
      fcntl(Fcntl::F_SETFL, flags)
    end
    STDERR.puts "Connected!"
  end
end
