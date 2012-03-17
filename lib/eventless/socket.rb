require 'socket'
require 'fcntl'

class BasicSocket < IO
  ##############
  # Sending data
  alias_method :syswrite_block, :syswrite
  def syswrite(*args)
    STDERR.puts "syswrite"
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

  alias_method :write_block, :write
  def write(str)
    STDERR.puts "write"

    str = str.to_s
    written = 0

    loop do
      written += syswrite(str[written, str.length])
      break if written == str.length
    end

    str.length
  end

  alias_method :sendmsg_block, :sendmsg
  def sendmsg(*args)
    STDERR.puts "sendmsg"
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      result = sendmsg_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitWritable
      fcntl(Fcntl::F_SETFL, flags)
      wait(Eventless.loop.io(:write, self))
      retry
    end

    result
  end

  def print(*objs)
    objs[0] = $_ if objs.size == 0

    objs.each_with_index do |obj, i|
      write($,) if $, and i > 0
      write(obj)
    end

    write($\) if $\ and objs.size > 0
  end

  ################
  # Receiving data
  BUFFER_LENGTH = 128*1024

  alias_method :sysread_block, :sysread
  def sysread(*args)
    STDERR.puts "sysread"
    buffer = ""
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      buffer << read_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitReadable
      fcntl(Fcntl::F_SETFL, flags)
      wait(Eventless.loop.io(:read, self))
      retry
    end

    buffer
  end

  def readpartial(length=nil, buffer=nil)
    raise ArgumentError if !length.nil? && length < 0
    STDERR.puts "readpartial"

    buffer = "" if buffer.nil?
    if byte_buffer.length >= length
      buffer << byte_buffer.slice!(0, length)
    elsif byte_buffer.length > 0
      buffer << byte_buffer.slice!(0, byte_buffer.length)
    else
      buffer << sysread(length)
    end

    buffer
  end


  alias_method :read_block, :read
  def read(length=nil, buffer=nil)
    raise ArgumentError if !length.nil? && length < 0
    STDERR.puts "read" unless length == 1

    return "" if length == 0
    buffer = "" if buffer.nil?

    if length.nil?
      loop do
        begin
          buffer << sysread(BUFFER_LENGTH)
        rescue EOFError
          break
        end
      end
    else
      if byte_buffer.length >= length
        return byte_buffer.slice!(0, length)
      elsif byte_buffer.length > 0
        buffer << byte_buffer.slice!(0, byte_buffer.length)
      end

      remaining = length - buffer.length
      while buffer.length < length && remaining > 0
        begin
          buffer << sysread(remaining > BUFFER_LENGTH ? remaining : BUFFER_LENGTH)
          remaining = length - buffer.length
        rescue EOFError
          break
        end
      end
    end

    return nil if buffer.length == 0
    if length and buffer.length > length
      byte_buffer << buffer.slice!(length, buffer.length)
    end

    buffer
  end

  alias_method :readchar_block, :readchar
  def readchar
    c = read(1)
    raise EOFError if c.nil?
    c
  end

  alias_method :getc_block, :getc
  def getc
    read(1)
  end

  alias_method :gets_block, :gets
  def gets(sep=$/, limit=nil)
    STDERR.puts "gets"

    if sep.kind_of? Numeric and limit.nil?
      limit = sep
      sep = $/
    end

    sep = "\n\n" if sep == ""
    str = ""
    if sep.nil?
      str = read
    else
      while str.index(sep).nil?
        c = read(1)
        break if c.nil?
        str << c
        break if not limit.nil? and str.length == limit
      end
    end

    $_ = str
    str
  end

  alias_method :recv_block, :recv
  def recv(*args)
    STDERR.puts "recv"
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      mesg = recv_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitReadable
      fcntl(Fcntl::F_SETFL, flags)
      wait(Eventless.loop.io(:read, self))
      retry
    end

    mesg
  end

  alias_method :recvmsg_block, :recvmsg
  def recvmsg(*args)
    STDERR.puts "recvmsg"
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      msg = recvmsg_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitReadable
      fcntl(Fcntl::F_SETFL, flags)
      wait(Eventless.loop.io(:read, self))
      retry
    end

    msg
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

  def byte_buffer
    @buffer ||= ""
  end

  def byte_buffer=(buffer)
    @buffer = buffer
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

  alias_method :accept_block, :accept
  def accept(*args)
    STDERR.puts "accept"
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      sock_pair = accept_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitReadable, Errno::EINTR
      fcntl(Fcntl::F_SETFL, flags)
      wait(Eventless.loop.io(:read, self))
      retry
    end

    sock_pair
  end

  alias_method :recvfrom_block, :recvfrom
  def recvfrom(*args)
    STDERR.puts "recvfrom"
    begin
      flags = fcntl(Fcntl::F_GETFL, 0)
      pair = recvfrom_nonblock(*args)
      fcntl(Fcntl::F_SETFL, flags)
    rescue IO::WaitReadable
      fcntl(Fcntl::F_SETFL, flags)
      wait(Eventless.loop.io(:read, self))
      retry
    end

    pair
  end

end

module Eventless
  AF_MAP = {}
  ::Socket.constants.grep(/^AF_/).each do |c|
    AF_MAP[Socket.const_get(c)] = c.to_s
  end

  class TCPSocket < ::Socket
    def initialize(remote_host, remote_port, local_host=nil, local_port=nil)
      super(:INET, :STREAM)
      connect(Socket.pack_sockaddr_in(remote_port, remote_host))

      if local_host && local_port
        bind(Socket.pack_sockaddr_in(local_port, local_host))
      end
    end

    def peeraddr(reverse_lookup=nil)
      reverse_lookup = should_reverse_lookup?(reverse_lookup)
      addr = remote_address

      name_info = reverse_lookup ? addr.getnameinfo[0] : addr.ip_address

      [AF_MAP[addr.afamily], addr.ip_port, name_info, addr.ip_address]
    end

    private
    def should_reverse_lookup?(reverse_lookup)
      case reverse_lookup
      when true, :hostname
        true
      when false, :numeric
        false
      when nil
        not do_not_reverse_lookup
      else
        if reverse_lookup.kind_of? Symbol
          raise TypeError, "wrong argument type #{reverse_lookup.class} (expected Symbol)"
        end

        raise ArgumentError, "invalid reverse_lookup flag: #{reverse_lookup}"
      end
    end
  end

  class TCPServer < ::Socket
    def initialize(hostname=nil, port)
      Addrinfo.foreach(hostname, port, nil, :STREAM, nil, Socket::AI_PASSIVE) do |ai|
        begin
          # I know calling super multiple times looks problematic, but after
          # reading through rsock_init_sock() in ext/socket/init.c, it looks
          # like as long as we make sure to close the extra file descripters,
          # it should be ok.
          super(ai.afamily, ai.socktype, ai.protocol)
          setsockopt(:SOCKET, :REUSEADDR, true)
          bind(ai)
        rescue
          close
        else
          break
        end
      end

      listen(5)
    end

    def accept
      TCPSocket.for_fd(super[0].fileno)
    end
  end
end

class TCPSocket
  class << self
    def new(*args)
      Eventless::TCPSocket.new(*args)
    end

    alias_method :open, :new
  end
end

class TCPServer
  class << self
    def new(*args)
      Eventless::TCPServer.new(*args)
    end

    alias_method :open, :new
  end
end
