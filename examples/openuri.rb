#!/usr/bin/env ruby

require 'bundler/setup'
require 'eventless'

require 'open-uri'

jobs = %w(74.125.226.240 74.125.226.241 74.125.226.242 74.125.226.243 74.125.226.244).map do |url|
  Eventless.spawn do
    open("http://#{url}/") { |f| puts f.read }
  end
end

jobs.each { |j| j.join }
