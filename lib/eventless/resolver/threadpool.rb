require 'socket'

require 'ipaddress'

require 'eventless/sockaddr'

module Eventless
  class IPSocket < BasicSocket
    def self.getaddress(hostname)
      queue = Queue.new
      watcher = Eventless.loop.async
      Eventless.loop.attach(watcher)

      Eventless.threadpool.schedule do
        addr = RealIPSocket.getaddress(hostname)
        queue << addr
        watcher.signal
      end
      Eventless.loop.transfer

      queue.shift
    end
  end

  class Socket < BasicSocket
    class << self
      def pack_sockaddr_in(port, host)
        debug_puts "Sockaddr.pack_sockaddr_in"

        ip = IPAddress.parse(IPSocket.getaddress(host))
        family = ip.ipv6? ? Socket::AF_INET6 : Socket::AF_INET

        Eventless::Sockaddr.pack_sockaddr_in(port, ip.to_s, family)
      end
      alias_method :sockaddr_in, :pack_sockaddr_in
    end
  end
end
