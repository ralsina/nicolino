require "./command.cr"

module Nicolino
  module Commands
    struct Serve < Command
      @@name = "serve"
      @@doc = <<-DOC
Serve the website over HTTP

Starts a local web server so you can see the site in your
browser.

Usage:
  nicolino serve [-c <file>][-q|-v <level>]

Options:
  -c <file>         Specify a config file to use [default: conf.yml]
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything
DOC

      def run : Int32
        make_server(live_reload: false).listen
        0
      rescue ex : Exception
        Log.error(exception: ex) { "Error serving site: #{ex.message}" }
        Log.debug { ex.backtrace.join("\n") }
        1
      end
    end
  end
end

Nicolino::Commands::Serve.register

def make_server(live_reload = false)
  handlers = [
    Handler::LiveReloadHandler.new,
    Handler::IndexHandler.new,
    HTTP::StaticFileHandler.new("output"),
  ]

  handlers.delete_at(0) if !live_reload

  server = HTTP::Server.new handlers
  address = server.bind_tcp 8080
  Log.info { "Server listening on http://#{address}" }
  server
end
