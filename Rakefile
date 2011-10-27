require 'bundler/gem_tasks'

SPECS = [
  "test/rubyspec/library/socket/basicsocket/close_read_spec.rb",
  "test/rubyspec/library/socket/basicsocket/close_write_spec.rb",
  "test/rubyspec/library/socket/basicsocket/for_fd_spec.rb",
  "test/rubyspec/library/socket/basicsocket/getsockname_spec.rb",
  "test/rubyspec/library/socket/basicsocket/getsockopt_spec.rb",
  "test/rubyspec/library/socket/basicsocket/recv_nonblock_spec.rb",
  "test/rubyspec/library/socket/basicsocket/setsockopt_spec.rb",
  "test/rubyspec/library/socket/basicsocket/shutdown_spec.rb"
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
    # sh "test/mspec/bin/mspec -t #{ENV["TARGET"] || "ruby" } -Ilib -reventless test/rubyspec/library/socket/"

    sh "test/mspec/bin/mspec -t #{ENV["TARGET"] || "ruby" } -Ilib -reventless #{SPECS.join(" ")}"

    # run without eventless
    #sh "test/mspec/bin/mspec -t #{ENV["TARGET"] || "ruby" } #{SPECS.join(" ")}"
  end
end

task :default => :spec
