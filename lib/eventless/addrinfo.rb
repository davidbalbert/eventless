require 'socket'

module Eventless
  RealAddrinfo = ::Addrinfo

  class Addrinfo
    def initialize(sockaddr, *rest)
      if sockaddr
        if sockaddr.class == RealAddrinfo
          @addrinfo = sockaddr
        else
          @addrinfo = RealAddrinfo.new(sockaddr, *rest)
        end
      end
    end

    def self._wrap(real_addrinfo)
      addrinfo = new(false)
      addrinfo.send(:addrinfo=, real_addrinfo)

      addrinfo
    end

    # wrapped instance methods
    [:afamily, :socktype, :protocol,
     :to_sockaddr, :ip_address, :ip_port].each do |sym|
      define_method(sym) do |*args|
        @addrinfo.send(sym, *args)
      end
    end

    def self.foreach(*args, &block)
      RealAddrinfo.foreach(*args, &block)
    end

    def self.getaddrinfo(*args)
      queue = Queue.new
      watcher = Eventless.loop.async
      Eventless.loop.attach(watcher)

      Eventless.threadpool.schedule do
        addrs = RealAddrinfo.getaddrinfo(*args).map { |ai| new(ai) }
        queue << addrs
        watcher.signal
      end
      Eventless.loop.transfer

      queue.shift
    end

    def getnameinfo(*args)
      queue = Queue.new
      watcher = Eventless.loop.async
      Eventless.loop.attach(watcher)

      Eventless.threadpool.schedule do
        nameinfo = @addrinfo.getnameinfo(*args)
        queue << nameinfo
        watcher.signal
      end
      Eventless.loop.transfer

      queue.shift
    end

    def inspect
      "#<Eventless::Addrinfo:#{@addrinfo.inspect.split("Addrinfo:").last.chop}>"
    end

    private

    def addrinfo=(addrinfo)
      @addrinfo = addrinfo
    end
  end
end

Object.send(:remove_const, :Addrinfo)
Addrinfo = Eventless::Addrinfo
