Eventless
=========

Eventless aspires to be a concurrent networking library for Ruby that lets you write asynchronous, event driven code that looks like normal, blocking code. It uses Fibers, so it requires Ruby 1.9. It also uses Marc Lehmann's libev (currently via cool.io). Eventless is inspired heavily by [gevent](http://gevent.org).

Right now it's all in one file and really more of an experiment, but I'm working hard on that.

##How it works

Eventless monkey patches `Socket` to make it's API asynchronous. All of your code runs in `Fiber`s. You can make new fibers using `Eventless.spawn`. `Fiber.new` _will not_ work. Your code should look exactly the same, but when you call something that normally blocks, your fiber gets put to sleep on the event loop and gets woken up when there is data to be read or written.

Because Eventless monkey patches the core library (eww, gross, I know), any networking library that is written in pure Ruby should just work (tm). You should eventually be able to write code like this:

```ruby
require 'eventless'
require 'open-uri'

jobs = %w(http://www.google.com/, http://github.com/, http://ruby-lang.org/).map do |url|
  Eventless.spawn do
    open(url) { |f| f.read }
  end
end

pages = Eventless.joinall(jobs)
```

It's really far away from that though. Right now you can just do this:

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
- `Socket#recv` and `Socket#connect`

###What doesn't work
- All the other `Socket` code.
- Everything else

I'm currently working on monkey patching `IO.select` so that `open-uri` and `Net::HTTP` will work correctly. This requires `Event`, an object to notify waiting coroutines. I am currently working on this.

##Contributing

The current goal is to replace all blocking methods in `Socket` with API compatible versions that transfer control to the event loop rather than block. When in doubt, read the code for gevent, but write your code like a Rubyist would.

##License

Eventless is licensed under the MIT License. See LICENSE for more information.
