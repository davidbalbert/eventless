Eventless
=========

Eventless aspires to be a concurrent networking library for Ruby that lets you write asynchronous, event driven code that looks like normal, blocking code. It uses Fibers, so it requires Ruby 1.9. It also uses Marc Lehmann's libev (currently via cool.io). Eventless is inspired heavily by [gevent](http://gevent.org).

Right now it's more of an experiment than an actual library, but I'm working hard on that.

##How it works

Eventless monkey patches `Socket` to make its API asynchronous. All of your code runs in a `Fiber`. You can make new fibers using `Eventless.spawn`. `Fiber.new` _will not_ work. Your code should look exactly the same, but when you call something that normally blocks, your fiber gets put to sleep on the event loop and gets woken up when there is data to be read or written.

Because Eventless monkey patches the core library (eww, gross, I know), any networking library that is written in pure Ruby should just work (tm). Currently Eventless has enough code in it to support open-uri, so you can do things like this:

```ruby
require 'eventless'
require 'open-uri'

# no async dns support yet, so we'll request IP addresses
# all of these are google.com
jobs = %w(74.125.226.240 74.125.226.241 74.125.226.242 74.125.226.243 74.125.226.244).map do |url|
  Eventless.spawn do
    open(url) { |f| f.read }
  end
end

pages = Eventless.joinall(jobs)
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

##Install

It will probably crash or not work, but:

    $ git clone git://github.com/davidbalbert/eventless.git
    $ cd eventless/examples # run some of these

##Status

###What works
- The event loop
- Exception handling in `Fiber`
- `Kernel#sleep`
- Timeouts
- `open-uri`
- `IO.select`
- `Socket#recv`, `Socket#connect`, `Socket#write`, and `TCPSocket.new`

###What doesn't work
- All the other `Socket` code.
- DNS resolution
- Everything else

##Contributing

The current goal is to replace all blocking methods in `Socket` with API compatible versions that transfer control to the event loop rather than block. When in doubt, read the code for gevent, but write your code like a Rubyist would.

##License

Eventless is licensed under the MIT License. See LICENSE for more information.
