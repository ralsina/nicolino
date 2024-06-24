# Run forever automatically rebuilding the site
def auto(options, arguments)
  load_config(options)
  create_tasks
  Croupier::TaskManager.fast_mode = options.bool.fetch("fastmode", false)

  # Now run in auto mode
  begin
    Log.info { "Running in auto mode, press Ctrl+C to stop" }
    # Launch HTTP server
    server = make_server(options, arguments, live_reload: true)
    spawn do
      server.listen
    end

    # Launch LiveReload server
    live_reload = LiveReload::Server.new
    Log.info { "LiveReload on http://#{live_reload.address}" }
    spawn do
      live_reload.listen
    end

    # Setup a watcher for posts/pages and trigger respawn if files
    # are added
    watcher = Inotify::Watcher.new
    watcher.watch("content", LibInotify::IN_CREATE)
    watcher.on_event do |_|
      server.close
      live_reload.http_server.close
      Process.exec(Process.executable_path.as(String), ["auto"] + ARGV)
    end

    # Create task that will be triggered in rebuilds
    Croupier::Task.new(
      id: "LiveReload",
      inputs: Croupier::TaskManager.tasks.keys,
      mergeable: false,
      proc: Croupier::TaskProc.new {
        modified = Set(String).new
        Croupier::TaskManager.modified.each do |path|
          next if path.lchop? "kv://"
          Croupier::TaskManager.depends_on(path).each do |p|
            next unless p.lchop? "output/"
            modified << Utils.path_to_link(p)
          end
        end
        modified.each do |p|
          Log.info { "LiveReload: #{p}" }
          live_reload.send_reload(path: p, liveCSS: p.ends_with?(".css"))
        end
      }
    )

    # First do a normal run
    arguments = Croupier::TaskManager.tasks.keys if arguments.empty?
    run(options, arguments)

    # Then run in auto mode
    Croupier::TaskManager.auto_run(arguments) # FIXME: check options
  rescue ex
    Log.error { ex }
    Log.debug { ex.backtrace.join("\n") }
    return 1
  end
  loop do
    sleep 1
  end
  0
end
