require "http/server"

module Server
  alias FilterProc = Proc(Bytes, Bytes)

  class Filter < IO
    def initialize(@proc : FilterProc, @context : HTTP::Server::Context)
      @io = @context.response.output
    end

    def write(slice : Bytes) : Nil
      @context.response.headers.delete("Content-Length")
      @io.write(@proc.call(slice))
      @io.flush
    end

    def close
      @io.close
    end

    def flush
      @io.flush
    end

    def read(slice : Bytes)
      raise NotImplementedError.new("read")
    end
  end

  class LiveReloadHandler
    include HTTP::Handler

    def call(context) : Nil
      if context.request.path.ends_with?(".html")
        context.response.output = Filter.new(
          FilterProc.new { |slice|
            data = String.new(slice) + %(<script src="http://localhost:35729/livereload.js"></script>)
            data.to_slice
          }, context)
      end
      call_next(context)
    end
  end
end
