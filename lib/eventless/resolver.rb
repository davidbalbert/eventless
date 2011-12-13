require 'socket'

require 'cares'

module Eventless
  class Loop
    SocketHandler = Struct.new(:read_watcher, :write_watcher)

    def setup_resolver
      @resolver_sockets = {}

      resolver = Cares.new do |socket, read, write|
        if read or write
          unless @resolver_sockets.has_key?(socket)
            # new socket
            attach(@resolver_timer) unless @resolver_timer.attached?

            handler = create_socket_watchers(socket)
            @resolver_sockets[socket] = handler
          end

          handler = @resolver_sockets[socket]

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
          detach(handler.read_handler) if handler.read_handler.attached?
          detach(handler.write_handler) if handler.write_handler.attached?

          @resolver_sockets.delete(socket)

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
    def create_socket_watchers(socket)
      handler = SocketHandler.new
      resolver = @resolver
      handler.read_watcher = io(:read, socket) do
        resolver.process_fd(socket, Cares::ARES_SOCKET_BAD)
      end
      handler.write_watcher = io(:write, socket) do
        resolver.process_fd(Cares::ARES_SOCKET_BAD, socket)
      end

      handler
    end
  end
end

class << IPSocket
  alias_method :old_getaddress, :getaddress

  def getaddress(hostname)
    fiber = Fiber.current
    addr = nil
    Eventless.resolver.gethostbyname(hostname, Socket::AF_UNSPEC) do |name, aliases, faimly, *addrs|
      addr = addrs[0]
      fiber.transfer
    end
    Eventless.loop.transfer

    addr
  end
end
