require 'socket'
require 'fcntl'

module Eventless
  RealBasicSocket = ::BasicSocket
  RealSocket = ::Socket
  RealIPSocket = ::IPSocket
  RealTCPSocket = ::TCPSocket
  RealTCPServer = ::TCPServer

  # We will do UDP sockets, but I haven't looked at them yet:
  RealUDPSocket = ::UDPSocket

  # I don't seem to have SOCKSSocket compiled into my ruby intepreter
  # RealSOCKSSocket = ::SOCKSSocket

  # Should we even support these?
  # RealUNIXSocket = ::UNIXSocket
  # RealUNIXServer = ::UNIXServer

  class BasicSocket
    def self._wrap(real_socket)
      sock = self.new(false)
      sock.__send__(:socket=, real_socket)

      sock
    end

    def self.for_fd(*args)
      new(*args)
    end

    def self.open(*args)
      if block_given?
        s = new(*args)
        result = nil
        begin
          result = yield s
        ensure
          s.close
        end

        result
      else
        new(*args)
      end
    end

    def self.stock_class_name
      stock_class_name = "Real#{self.name.split("::").last}"
    end

    def self.stock_class
      Eventless.const_get(stock_class_name)
    end

    # Copy over all constants from RealBasicSocket
    #
    # We're not just using Module.const_missing, for speed of constant lookup
    # which presumably happens a lot
    RealBasicSocket.constants.each do |c|
      self.const_set(c, RealBasicSocket.const_get(c))
    end

    # and for everyone who sublcasses us
    def self.inherited(child)
      if Eventless.const_defined? child.stock_class_name
        child.stock_class.constants.each do |c|
          child.const_set(c, child.stock_class.const_get(c))
        end
      end
    end

    # Needed for libraries that define constants under the classes we wrap
    # (*Socket, IO). This will be most common for c extensions that use the
    # extern variables set up in ruby.h to reference commonly used classes
    # (e.g. rb_cIO for IO).
    def self.const_missing(const)
      stock_class.const_get(const)
    end

    # methods to pass through to @socket defined on IO:
    [:closed?, :close, :read_nonblock, :fileno].each do |sym|
      define_method(sym) do |*args|
        @socket.__send__(sym, *args)
      end
    end

    # IO.new is the same as IO.for_fd
    def initialize(fd, *rest)
      if fd
        @socket = self.class.stock_class.for_fd(fd, *rest)
      end
    end

    ##############
    # Sending data
    def syswrite(*args)
      STDERR.puts "syswrite"
      begin
        flags = @socket.fcntl(Fcntl::F_GETFL, 0)
        result = @socket.write_nonblock(*args)
        @socket.fcntl(Fcntl::F_SETFL, flags)
      rescue IO::WaitWritable, Errno::EINTR
        @socket.fcntl(Fcntl::F_SETFL, flags)
        wait(Eventless.loop.io(:write, self))
        retry
      end

      result
    end

    def write(str)
      STDERR.puts "write"

      str = str.to_s
      written = 0

      loop do
        written += syswrite(str.byteslice(written, str.bytesize - written))
        break if written == str.bytesize
      end

      str.bytesize
    end

    def sendmsg(*args)
      STDERR.puts "sendmsg"
      begin
        flags = @socket.fcntl(Fcntl::F_GETFL, 0)
        result = @socket.sendmsg_nonblock(*args)
        @socket.fcntl(Fcntl::F_SETFL, flags)
      rescue IO::WaitWritable
        @socket.fcntl(Fcntl::F_SETFL, flags)
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

      nil
    end

    def putc(arg)
      ret = arg
      arg = arg.to_int.chr if arg.is_a?(Numeric)
      write(arg.to_s[0])

      ret
    end

    def puts(*args)
      STDERR.puts "puts"

      if args.empty?
        write("\n")
      else
        args.each do |arg|
          ary = Array.try_convert(arg)
          if ary
            puts *ary
          else
            arg = arg.to_s
            write(arg)
            write("\n") unless arg[-1] == "\n"
          end
        end
      end

      nil
    end

    ################
    # Receiving data
    BUFFER_LENGTH = 128*1024

    def sysread(*args)
      STDERR.puts "sysread"
      buffer = ""
      begin
        flags = @socket.fcntl(Fcntl::F_GETFL, 0)
        buffer << @socket.read_nonblock(*args)
        @socket.fcntl(Fcntl::F_SETFL, flags)
      rescue IO::WaitReadable
        @socket.fcntl(Fcntl::F_SETFL, flags)
        wait(Eventless.loop.io(:read, self))
        retry
      end

      buffer
    end

    def readpartial(length, buffer=nil)
      length = length.to_int
      raise ArgumentError if length < 0
      STDERR.puts "readpartial"

      buffer.clear if buffer
      buffer = "" if buffer.nil?

      if byte_buffer.bytesize >= length
        buffer << byte_buffer.byteslice!(0, length)
      elsif byte_buffer.bytesize > 0
        buffer << byte_buffer.byteslice!(0, byte_buffer.bytesize)
      else
        buffer << sysread(length)
      end

      buffer
    end

    def read(length=nil, buffer=nil)
      raise ArgumentError if !length.nil? && length < 0
      STDERR.puts "read" unless length == 1

      return "" if length == 0
      buffer.clear if buffer
      buffer = "" if buffer.nil?

      bytes = ByteBuffer.new

      if length.nil?
        loop do
          begin
            bytes << sysread(BUFFER_LENGTH)
          rescue EOFError
            break
          end
        end
      else
        if byte_buffer.bytesize >= length
          return byte_buffer.byteslice!(0, length)
        elsif byte_buffer.bytesize > 0
          bytes << byte_buffer.byteslice!(0, byte_buffer.bytesize)
        end

        remaining = length - bytes.bytesize
        while bytes.bytesize < length && remaining > 0
          begin
            bytes << sysread(remaining > BUFFER_LENGTH ? BUFFER_LENGTH : remaining)
            remaining = length - bytes.bytesize
          rescue EOFError
            break
          end
        end
      end

      return nil if bytes.bytesize == 0
      if length and bytes.bytesize > length
        byte_buffer << bytes.byteslice!(length, buffer.bytesize)
      end
      buffer << bytes.to_s

      buffer
    end

    def readchar
      c = read(1)
      raise EOFError if c.nil?
      c
    end

    def getc
      read(1)
    end

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

    def recv(*args)
      STDERR.puts "recv"
      begin
        flags = @socket.fcntl(Fcntl::F_GETFL, 0)
        mesg = @socket.recv_nonblock(*args)
        @socket.fcntl(Fcntl::F_SETFL, flags)
      rescue IO::WaitReadable
        @socket.fcntl(Fcntl::F_SETFL, flags)
        wait(Eventless.loop.io(:read, self))
        retry
      end

      mesg
    end

    def recvmsg(*args)
      STDERR.puts "recvmsg"
      begin
        flags = @socket.fcntl(Fcntl::F_GETFL, 0)
        msg = @socket.recvmsg_nonblock(*args)
        @socket.fcntl(Fcntl::F_SETFL, flags)
      rescue IO::WaitReadable
        @socket.fcntl(Fcntl::F_SETFL, flags)
        wait(Eventless.loop.io(:read, self))
        retry
      end

      msg
    end

    def remote_address
      Addrinfo._wrap(@socket.remote_address)
    end

    private

    # connect is private so we can call it from both Socket and TCPSocket
    def connect(*args)
      STDERR.puts "connect"
      begin
        flags = @socket.fcntl(Fcntl::F_GETFL, 0)
        @socket.connect_nonblock(*args)
        @socket.fcntl(Fcntl::F_SETFL, flags)
      rescue IO::WaitWritable
        @socket.fcntl(Fcntl::F_SETFL, flags)
        #STDERR.puts "connect: about to sleep"
        wait(Eventless.loop.io(:write, self))
        retry
      rescue Errno::EISCONN
        @socket.fcntl(Fcntl::F_SETFL, flags)
      end
      #STDERR.puts "Connected!"
    end

    # accept is private so we can call it from both Socket and TCPServer
    def accept
      STDERR.puts "accept"
      begin
        flags = @socket.fcntl(Fcntl::F_GETFL, 0)
        real_socket, real_addrinfo = @socket.accept_nonblock
        @socket.fcntl(Fcntl::F_SETFL, flags)
      rescue IO::WaitReadable, Errno::EINTR
        @socket.fcntl(Fcntl::F_SETFL, flags)
        wait(Eventless.loop.io(:read, self))
        retry
      end

      sock = Socket._wrap(real_socket)
      addrinfo = Addrinfo._wrap(real_addrinfo)

      [sock, addrinfo]
    end

    def bind(addr)
      STDERR.puts "bind"

      # bind() can also take an Addrinfo, but it does a strict type check
      # before converting. Because Eventless::Addrinfo isn't an Addrinfo, we
      # have to do the conversion ourselves.
      addr = addr.to_sockaddr if addr.respond_to? :to_sockaddr
      @socket.bind(addr)
    end

    # XXX: eventually this may have a second command called timeout
    def wait(watcher)
      Eventless.loop.attach(watcher)
      begin
        Eventless.loop.transfer
      ensure
        watcher.detach
      end
    end

    def socket=(socket)
      @socket = socket
    end

    def socket
      @socket
    end

    def byte_buffer
      @buffer ||= ByteBuffer.new
    end

    def byte_buffer=(buffer)
      @buffer = ByteBuffer.new(buffer)
    end
  end

  class Socket < BasicSocket
    def self.for_fd(*args)
      sock = new(false, false)
      sock.__send__(:socket=, stock_class.for_fd(*args))

      sock
    end

    def self._wrap(real_socket)
      sock = new(false, false)
      sock.__send__(:socket=, real_socket)

      sock
    end

    def initialize(domain, socktype, protocol=nil)
      unless domain == false
        @socket = self.class.stock_class.new(domain, socktype, protocol)
      end
    end

    class << self
      # class methods to pass through to @socket defined on RealSocket:
      [:gethostname].each do |sym|
        define_method(sym) do |*args|
          self.stock_class.__send__(sym, *args)
        end
      end
    end

    # instance methods
    [:listen].each do |sym|
      define_method(sym) do |*args|
        @socket.__send__(sym, *args)
      end
    end

    def connect(*args)
      super(*args)
    end

    def accept(*args)
      super(*args)
    end

    def bind(*args)
      super(*args)
    end

    def recvfrom(*args)
      STDERR.puts "recvfrom"
      begin
        flags = @socket.fcntl(Fcntl::F_GETFL, 0)
        pair = @socket.recvfrom_nonblock(*args)
        @socket.fcntl(Fcntl::F_SETFL, flags)
      rescue IO::WaitReadable
        @socket.fcntl(Fcntl::F_SETFL, flags)
        wait(Eventless.loop.io(:read, self))
        retry
      end

      pair
    end
  end

  AF_MAP = {}
  Socket.constants.grep(/^AF_/).each do |c|
    AF_MAP[Socket.const_get(c)] = c.to_s
  end

  class IPSocket < BasicSocket

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
        not @socket.do_not_reverse_lookup
      else
        if reverse_lookup.kind_of? Symbol
          raise TypeError, "wrong argument type #{reverse_lookup.class} (expected Symbol)"
        end

        raise ArgumentError, "invalid reverse_lookup flag: #{reverse_lookup}"
      end
    end
  end

  class TCPSocket < IPSocket
    class << self
      alias_method :open, :new

      def for_fd(*args)
        sock = new(false, false)
        sock.__send__(:socket=, stock_class.for_fd(*args))

        sock
      end
    end

    def initialize(remote_host, remote_port, local_host=nil, local_port=nil)
      unless remote_host == false
        @socket = RealSocket.new(:INET, :STREAM)
        connect(Socket.pack_sockaddr_in(remote_port, remote_host))

        if local_host && local_port
          @socket.bind(Socket.pack_sockaddr_in(local_port, local_host))
        end
      end
    end

    private
    def connect(*args)
      super(*args)
    end

  end

  class TCPServer < TCPSocket
    class << self
      alias_method :open, :new
    end

    def initialize(hostname=nil, port)
      unless hostname == false and port == false
        queue = Queue.new

        Eventless.threadpool.schedule do
          socket = nil
          Addrinfo.foreach(hostname, port, nil, :STREAM, nil, Socket::AI_PASSIVE) do |ai|
            begin
              socket = RealSocket.new(ai.afamily, ai.socktype, ai.protocol)
              socket.setsockopt(:SOCKET, :REUSEADDR, true)
              socket.bind(ai.to_sockaddr)
            rescue
              socket.close
            else
              break
            end
          end
          queue << socket
        end

        @socket = queue.shift
        @socket.listen(5)
      end
    end

    def accept
      TCPSocket.for_fd(super[0].fileno)
    end
  end

  class UDPSocket < IPSocket
    def initialize
      raise "Eventless::UDPSocket hasn't been implemented yet."
    end
  end

 class ByteBuffer < String
    def binslice!(*args)
      old_enc = encoding

      force_encoding('BINARY')
      ret = slice!(*args)
      force_encoding(old_enc)

      ret.force_encoding(old_enc)

      ret
    end
  end
end

Object.class_eval do
  remove_const(:BasicSocket)
  remove_const(:Socket)
  remove_const(:IPSocket)
  remove_const(:TCPSocket)
  remove_const(:TCPServer)
  remove_const(:UDPSocket)

  const_set(:BasicSocket, Eventless::BasicSocket)
  const_set(:Socket, Eventless::Socket)
  const_set(:IPSocket, Eventless::IPSocket)
  const_set(:TCPSocket, Eventless::TCPSocket)
  const_set(:TCPServer, Eventless::TCPServer)
  const_set(:UDPSocket, Eventless::UDPSocket)
end
