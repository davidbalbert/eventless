Eventless
=========

Eventless aspires to be a concurrent networking library for Ruby that lets you write asynchronous, event driven code that looks like normal, blocking code. It uses Fibers, so it requires Ruby 1.9. It also uses Marc Lehmann's libev via Tony Arcieri's cool.io. Eventless is inspired heavily by [gevent](http://gevent.org).

Right now it's more of an experiment than an actual library, but I'm working hard on that.

##How it works

Eventless monkey patches `Socket` to make its API asynchronous. All of your code runs in a `Fiber`. You can make new fibers using `Eventless.spawn`. `Fiber.new` _will not_ work. Your code should look exactly the same, but when you call something that normally blocks, your fiber gets put to sleep on the event loop and gets woken up when there is data to be read or written.

##How to use it

Because Eventless monkey patches the core library (eww, gross, I know), any networking library that is written in pure Ruby should just work (tm). Currently Eventless has enough code in it to support open-uri, so you can do things like this:

```ruby
require 'eventless'
require 'open-uri'

fibers = %w(http://www.google.com/ http://www.ruby-lang.org/ http://www.github.com/).map do |url|
  Eventless.spawn do
    open("http://#{url}/") { |f| puts f.read }
  end
end

fibers.each { |f| f.join }
```

You can also do this, which is admittedly, pretty silly:

```ruby
require 'eventless'

fibers = []
5.times do
  fibers << Eventless.spawn { sleep 2 }
end

fibers.each { |f| f.join }
```

Even though you've spawned five fibers that sleep for two seconds a piece, this code should only take two seconds to run.

###Threads

Eventless has very experimental support for monkeypatching `Thread.new` to spawn a `Fiber` instead, effectively turing multithreaded programs into single threaded, evented programs. This doesn't work well yet and it is currently an explicit opt-in by putting `require 'eventless/thread'` in your code.

##Install

It will probably crash or not work, but:

    $ git clone git://github.com/davidbalbert/eventless.git
    $ cd eventless
    $ bundle install
      ...
    $ cd eventless/examples # run some of these

##Test

This doesn't really work yet, but here's the start. Eventless is going to test against rubyspec. Here's how you do it:

    $ rake spec:deps # clones rubyspec and mspec
    $ rake spec # right now this just runs the socket specs without eventless

By default mspec will test against the `ruby` binary. You can specify the binary name or path by setting TARGET:

    $ TARGET=ruby19 rake spec
    $ TARGET=/usr/local/bin/ruby rake spec

Remember, right now Eventless only works on Ruby 1.9.

##Status

###What works
- The event loop
- Exception handling in `Fiber`
- `Kernel#sleep`
- `IO.select`
- `Socket#recv`, `Socket#connect`, `Socket#write`, and `TCPSocket.new`
- `IO#read*` and `IO#sysread` (for sockets only)
- `IO#get*` (but I haven't really tested them)
- `IO#write*`
- `timeout.rb`
- `open-uri`
- DNS resolution for `IPSocket.getaddress` and `Socket.(pack_)sockaddr_in`

###What doesn't work
- All the other `Socket` code.
- All other DNS resolution including `Addrinfo` class
- Everything else

##Contributing

The current goal is to replace all blocking methods in `Socket` with API compatible versions that transfer control to the event loop rather than block. When in doubt, read the code for gevent, but write your code like a Rubyist would.

Currently we are trying to monkey patch all the methods in the stock Ruby `socket` library.  The script in `script/socket_coverage.rb` can be used to how many methods have and have not been reimplemented eventless' socket library:

    $ ruby script/socket_coverage.rb
    Eventless::BasicSocket is 17.39% complete [4/23]
    Eventless::Socket is 16.22% complete [6/37]
    Eventless::IPSocket is 50% complete [2/4]
    Eventless::TCPSocket is 0% complete [0/1]
    Eventless::TCPServer is 25% complete [1/4]
    Eventless::UDPSocket is 0% complete [0/4]

The `-v` option can be used for a more verbose output, which includes method names:

    $ ruby script/socket_coverage.rb -v
    Eventless::BasicSocket is 17.92% complete [19/106]
        Implemented
          ::open
      	  ::for_fd
      	  #write
	  ...

##License

Eventless is licensed under the MIT License. See LICENSE for more information.
