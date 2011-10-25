require 'bundler/gem_tasks'

namespace :spec do
  desc "Ensure spec dependencies are installed"
  task :deps do
    sh "git submodule init"
    sh "git submodule update"
  end
end

if Dir['test/mspec/*'].empty? or Dir['test/rubyspec/*'].empty?
  task :spec do
    abort "Run `rake spec:deps` to be able to run the specs"
  end
else
  desc "Run specs"
  task :spec do
    # this doesn't really work. It doesn't load eventless first
    sh "test/mspec/bin/mspec -t #{ENV["TARGET"] || "ruby" } -Ilib -reventless test/rubyspec/library/socket/"
  end
end

task :default => :spec
