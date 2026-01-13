require "./command.cr"

module Nicolino
  module Commands
    # Run forever automatically rebuilding the site
    struct Auto < Command
      @@name = "auto"
      @@doc = <<-DOC
Run forever automatically rebuilding the site

This command will run the site in auto mode, monitoring
files for changes and triggering rebuilds. Also, if you
have a page open in a browser, it will trigger a reload.

Usage:
  nicolino auto [TARGET...] [--fast-mode][-c <file>]
                [-q|-v <level>]

Options:
  -c <file>         Specify a config file to use [default: conf.yml]
  --fast-mode       Use file timestamps rather than contents to
                    decide rebuilds.
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything
DOC

      def run : Int32
        create_tasks
        fast_mode = !@options.fetch("--fast-mode", nil).nil?
        Croupier::TaskManager.fast_mode = fast_mode
        arguments = @options.fetch("TARGET", [] of String).as(Array(String))

        # Now run in auto mode
        Log.info { "Running in auto mode, press Ctrl+C to stop" }
        # Launch HTTP server
        server = make_server(live_reload: true)
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
          Process.exec(Process.executable_path.as(String), ARGV)
        end

        # Create task that will be triggered in rebuilds
        Croupier::Task.new(
          id: "LiveReload",
          inputs: Croupier::TaskManager.tasks.keys,
          mergeable: false
        ) do
          modified = Set(String).new
          Croupier::TaskManager.modified.each do |path|
            next if path.lchop? "kv://"
            Croupier::TaskManager.depends_on(path).each do |dep|
              next unless dep.lchop? "output/"
              modified << Utils.path_to_link(dep)
            end
          end
          modified.each do |path|
            Log.info { "LiveReload: #{path}" }
            live_reload.send_reload(path: path, liveCSS: path.ends_with?(".css"))
          end
        end

        # First do a normal run
        arguments = Croupier::TaskManager.tasks.keys if arguments.empty?
        # TODO: see if any other combination of args is a good idea
        run(arguments, fast_mode: fast_mode)

        # Then run in auto mode
        Croupier::TaskManager.auto_run(arguments) # FIXME: check options
        loop do
          ::sleep(1.second)
        end
        0
        # rescue ex : Exception
        #   Log.error(exception: ex) { "Error running in auto mode: #{ex.message}" }
        #   Log.debug { ex.backtrace.join("\n") }
        #   1
      end
    end
  end
end

Nicolino::Commands::Auto.register
