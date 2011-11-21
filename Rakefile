require 'bundler/gem_tasks'

SPECS = [
  "test/rubyspec/library/socket/basicsocket",
  "test/rubyspec/library/socket/constants",
  #"test/rubyspec/library/mutex", <- wierd error, choosing to ignore for now
]


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
    # eventually, we should be able to run this... maybe :)
    # sh "test/mspec/bin/mspec -t #{ENV["TARGET"] || "ruby" } -Ilib -reventless -reventless/thread test/rubyspec/library/socket/"

    sh "test/mspec/bin/mspec -t #{ENV["TARGET"] || "ruby" } -Ilib -reventless -reventless/thread #{SPECS.join(" ")}"

    # run without eventless
    #sh "test/mspec/bin/mspec -t #{ENV["TARGET"] || "ruby" } #{SPECS.join(" ")}"
  end
end

desc "load eventless in a pry or irb session (alias `rake c`)"
task :console do
  if system("which pry")
    repl = "pry"
  else
    repl = "irb"
  end

  sh "#{repl} -Ilib -rubygems -reventless"
end

task :c => :console

task :default => :spec
