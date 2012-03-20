require 'socket'
require 'thread'

module Eventless
  RealAddrinfo = ::Addrinfo

  class Addrinfo
    def initialize(addrinfo)
      @addrinfo = addrinfo
    end

    # wrapped instance methods
    [:afamily, :socktype, :protocol, :to_sockaddr].each do |sym|
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
      Thread.new do
        addrs = RealAddrinfo.getaddrinfo(*args).map { |ai| new(ai) }
        queue << addrs
        watcher.signal
      end
      Eventless.loop.transfer

      queue.shift
    end

    def inspect
      "#<Eventless::Addrinfo:#{@addrinfo.inspect.split("Addrinfo:").last.chop}>"
    end
  end
end

Object.send(:remove_const, :Addrinfo)
Addrinfo = Eventless::Addrinfo
