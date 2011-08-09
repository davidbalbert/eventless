#require 'eventless/version'
require 'socket'
require 'fcntl'

STDIN.sync = STDOUT.sync = true

module Eventless
  class Loop
    def initialize
      @read_fds,  @write_fds, @error_fds = [], [], []
    end
    def run
      @running = true
      while @running
        IO::select(@read_fds, @write_fds, @error_fds)
      end
    end
  end
end

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
      STDOUT.puts "about to select"
      IO.select([self])
      retry
    end
    mesg
  end
end

serv = TCPServer.new("127.0.0.1", 12345)
af, port, host, addr = serv.addr
s = serv.accept
puts s.recv(10)
