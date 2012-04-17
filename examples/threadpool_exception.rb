#!/usr/bin/env ruby

require 'bundler/setup'

require 'eventless'

Eventless.threadpool.schedule do
  raise Exception, "Exception in the threadpool"
end

sleep 2
