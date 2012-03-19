require 'socket'

require 'cares'
require 'ipaddress'

require 'eventless/sockaddr'

module Eventless
  class Loop
    SocketHandler = Struct.new(:read_watcher, :write_watcher)

    def setup_resolver
      @resolver_sockets = {}

      resolver = Cares.new do |socket, read, write|
        handler = @resolver_sockets[socket.fileno]

        if read or write
          if handler.nil?
            # new socket
            attach(@resolver_timer) unless @resolver_timer.attached?

            handler = create_socket_watchers(socket)
            @resolver_sockets[socket.fileno] = handler
          end

          if read
            attach(handler.read_watcher)
          else
            detach(handler.read_watcher) if handler.read_watcher.attached?
          end

          if write
            attach(handler.write_watcher)
          else
            detach(handler.write_watcher) if handler.write_watcher.attached?
          end

        else # socket just got closed
          detach(handler.read_watcher) if handler.read_watcher.attached?
          detach(handler.write_watcher) if handler.write_watcher.attached?

          @resolver_sockets.delete(socket.fileno)

          if @resolver_sockets.size == 0
            detach(@resolver_timer)
          end
        end
      end

      @resolver_timer = timer(1, true) do
        resolver.process_fd(Cares::ARES_SOCKET_BAD, Cares::ARES_SOCKET_BAD)
      end

      @resolver = resolver
    end

    ########################################################################
    private

    # TODO: these SocketErrors are thrown in the context of the eventloop,
    # which means that one dns error will probably kill the entire system! This
    # is very bad! I'm not sure the best way to handle this one. I think I may
    # have to add error callbacks to ruby-cares
    def create_socket_watchers(socket)
      handler = SocketHandler.new
      resolver = @resolver
      handler.read_watcher = io(:read, socket) do
        begin
          resolver.process_fd(socket, Cares::ARES_SOCKET_BAD)
        rescue Cares::CaresError => e
          raise SocketError, e.message
        end
      end
      handler.write_watcher = io(:write, socket) do
        begin
          resolver.process_fd(Cares::ARES_SOCKET_BAD, socket)
        rescue Cares::CaresError => e
          raise SocketError, e.message
        end
      end

      handler
    end
  end

  class IPSocket < BasicSocket
    def self.getaddress(hostname)
      # return if we're already a valid ip address
      begin
        IPAddress.parse hostname
        return hostname
      rescue
      end

      fiber = Fiber.current
      addr = nil
      Eventless.resolver.gethostbyname(hostname, Socket::AF_UNSPEC) do |name, aliases, faimly, *addrs|
        addr = addrs[0]

        # XXX: I thought calling fiber.transfer(addrs[0]) would make
        # Eventless.loop.transfer return addrs[0], but it doesn't. I'm not sure
        # why. If anyone knows how to fix it, let me know. I think closing around
        # addr is a bit hacky.
        fiber.transfer
      end
      Eventless.loop.transfer

      addr
    end
  end

  class Socket < BasicSocket
    class << self
      def pack_sockaddr_in(port, host)
        STDERR.puts "Sockaddr.pack_sockaddr_in"

        ip = IPAddress.parse(IPSocket.getaddress(host))
        family = ip.ipv6? ? Socket::AF_INET6 : Socket::AF_INET

        Eventless::Sockaddr.pack_sockaddr_in(port, ip.to_s, family)
      end
      alias_method :sockaddr_in, :pack_sockaddr_in
    end
  end
end
