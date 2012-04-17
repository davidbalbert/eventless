if ENV['DEBUG']
  def debug_puts(*args)
    STDERR.puts(*args)
  end
else
  def debug_puts(*args); end
end
