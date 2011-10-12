module Eventless
  module Linkable
    def link(obj, method)
      links << [obj, method]
      # XXX: should make this check if the fiber is already dead and then
      # schedule immediately
    end

    def unlink(obj, method)
      links.delete([obj, method])
    end

    def notify_links!
      watcher = Eventless.loop.timer(0) do
        links.each { |obj, method| obj.send(method, self) }
      end
      Eventless.loop.attach(watcher)
    end
  end
end
