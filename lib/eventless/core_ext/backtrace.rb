class Object
  def backtrace
    raise
  rescue Exception => e
    e.backtrace[1..-1]
  end
end
