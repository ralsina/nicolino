def make_server(options, arguments, live_reload = false)
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

def serve(options, arguments, live_reload = false)
  load_config(options)
  make_server(options, arguments, live_reload).listen
end
