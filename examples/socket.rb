# none of this works. it's just scratch space

#serv = TCPServer.new("127.0.0.1", 12345)
#af, port, host, addr = serv.addr
#s = serv.accept
#puts s.recv(10)


def eventless_get(host)
  s = Socket.new(:INET, :STREAM)
  sockaddr = Socket.pack_sockaddr_in(80, host)
  s.connect(sockaddr)
  s.write( "GET / HTTP/1.0\r\n\r\n" )
  site = ""
  loop do
    str = s.recv(100000)
    site << str
    # puts str
    break if str == ""
  end

  STDERR.puts "#{host}: #{site.size}"
  puts site
end

#jobs = %w(www.google.com news.ycombinator.com).map do |url|
# jobs = %w(dave.is www.nick.is).map do |url|
  # Eventless.spawn { eventless_get(url) }
# end

# STDERR.puts jobs
