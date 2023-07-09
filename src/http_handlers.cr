require "http/server"
require "lexbor"

module Handler
  alias FilterProc = Proc(Bytes, Bytes)

  # A filtering IO for HTTP server contexts
  # Takes a FilterProc which takes the next handler's
  # output and modifies it
  class Filter < IO
    def initialize(
      @proc : FilterProc,
      @context : HTTP::Server::Context
    )
      @io = @context.response.output
    end

    def write(slice : Bytes) : Nil
      @context.response.headers.delete("Content-Length")
      @io.write(@proc.as(FilterProc).call(slice))
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

  alias HTMLFilterProc = Proc(Lexbor::Parser, Nil)

  # A HTMLFilter that uses Lexbor to modify the HTML
  class HTMLFilter < Filter
    def initialize(htmlproc : HTMLFilterProc, @context : HTTP::Server::Context)
      @io = @context.as(HTTP::Server::Context).response.output
      @proc = FilterProc.new { |slice|
        parser = Lexbor::Parser.new(slice)
        htmlproc.call(parser)
        parser.to_pretty_html.to_slice
      }
    end
  end

  # A handler that redirects to index.html if the path
  # is a directory
  class IndexHandler
    include HTTP::Handler

    def call(context) : Nil
      if context.request.path.ends_with?("/")
        # Redirect to whatever/index.html
        context.response.status_code = 302
        context.response.headers["Location"] = context.request.path + "index.html"
      else
        call_next(context)
      end
    end
  end

  # A handler that injects a script tag for livereload
  # using a HTMLFilter
  class LiveReloadHandler
    include HTTP::Handler

    def call(context) : Nil
      if context.request.path.ends_with?(".html")
        context.response.output = HTMLFilter.new(
          HTMLFilterProc.new { |doc|
            s = doc.create_node(:script)
            s["src"] = "http://localhost:35729/livereload.js"
            doc.head!.append_child(s)
          }, context)
      end
      call_next(context)
    end
  end
end
