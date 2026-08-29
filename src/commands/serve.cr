require "./command.cr"

module Nicolino
  module Commands
    # nicolino serve comand
    struct Serve < Command
      @@name = "serve"
      @@doc = <<-DOC
        Serve the website over HTTP

        Starts a local web server so you can see the site in your
        browser at http://localhost:8080

        Usage:
          nicolino serve [--help][--port <port>][-c <file>][-q|-v <level>]

        Options:
          --help            Show this help message
          --port <port>     Port to listen on [default: 8080]
          -c <file>         Specify a config file to use [default: conf.yml]
          -v level          Control the verbosity, 0 to 6
          -q                Don't log anything
        DOC

      def run : Int32
        port = @options.fetch("--port", "8080").as(String).to_i
        make_server(live_reload: false, port: port).listen
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

def make_server(live_reload = false, port = 8080)
  handlers = [] of HTTP::Handler
  handlers << Handler::LiveReloadHandler.new if live_reload
  handlers << Handler::IndexHandler.new
  handlers << HTTP::StaticFileHandler.new("output")

  server = HTTP::Server.new handlers
  address = server.bind_tcp port
  Log.info { "Server listening on http://#{address}" }
  server
end
