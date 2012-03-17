#!/usr/bin/env ruby

require 'bundler/setup'
require 'eventless'

require 'open-uri'

jobs = %w(http://www.google.com/ http://www.ruby-lang.org/ http://www.github.com/).map do |url|
  Eventless.spawn do
    open("http://www.google.com/") do |f|
      puts f.read
    end
  end
end

jobs.each { |j| j.join }
