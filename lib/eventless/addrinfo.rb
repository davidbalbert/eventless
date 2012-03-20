require 'socket'
require 'thread'

module Eventless
  RealAddrinfo = ::Addrinfo

  class Addrinfo
    def initialize(addrinfo)
      @addrinfo = addrinfo
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
  end
end

Object.send(:remove_const, :Addrinfo)
Addrinfo = Eventless::Addrinfo
