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
  nicolino auto [--help][TARGET...] [--fast-mode][-c <file>]
                [-q|-v <level>]

Options:
  --help            Show this help message
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

        # Set up hook to reload config before tasks run
        Croupier::TaskManager.before_run_hook = ->(modified_files : Set(String)) {
          return unless modified_files.includes?(Config.config_path)
          Log.info { "Config file changed, reloading..." }
          Config.reload
        }

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
        # are added, deleted, or moved
        watcher = Inotify::Watcher.new(recursive: true)
        watch_flags = LibInotify::IN_CREATE | LibInotify::IN_DELETE | LibInotify::IN_MOVED_FROM | LibInotify::IN_MOVED_TO
        watcher.watch("content", watch_flags)
        spawn do
          watcher.on_event do |_|
            # Add a small delay to ensure the file operation is complete
            sleep 0.2.seconds
            server.close
            live_reload.http_server.close
            Process.exec(Process.executable_path.as(String), ARGV)
          end
        end

        # Create task that will be triggered in rebuilds
        Croupier::Task.new(
          id: "LiveReload",
          inputs: Croupier::TaskManager.tasks.keys,
          mergeable: false
        ) do
          modified = Set(String).new
          style_css_changed = false
          Croupier::TaskManager.modified.each do |path|
            next if path.lchop? "kv://"
            Croupier::TaskManager.depends_on(path).each do |dep|
              next unless dep.lchop? "output/"
              link = Utils.path_to_link(dep)
              # Check if style.css changed - this requires full page reload
              # because fonts, color schemes, or @import rules may have changed
              style_css_changed = true if link == "/css/style.css"
              modified << link
            end
          end

          # If style.css changed, force reload all HTML pages
          # We need to reload all HTML pages because they all include style.css
          # and the changes (fonts, @import) require full page refresh
          if style_css_changed
            # Find all HTML files in output
            html_pages = modified.select(&.ends_with?(".html"))
            if html_pages.empty?
              # If no HTML pages were directly modified, search for all HTML outputs
              Croupier::TaskManager.tasks.each do |_, task|
                html_output = task.outputs.find(&.ends_with?(".html"))
                if html_output
                  html_pages << Utils.path_to_link(html_output)
                end
              end
            end
            Log.info { "LiveReload: style.css changed, forcing full page reload for #{html_pages.size} pages" }
            html_pages.each do |page|
              Log.info { "LiveReload: #{page}" }
              live_reload.send_reload(path: page, liveCSS: false)
            end
          else
            modified.each do |path|
              Log.info { "LiveReload: #{path}" }
              live_reload.send_reload(path: path, liveCSS: path.ends_with?(".css"))
            end
          end
        end

        # First do a normal run
        arguments = Croupier::TaskManager.tasks.keys if arguments.empty?
        # TODO: see if any other combination of args is a good idea
        begin
          run(arguments, fast_mode: fast_mode)
          # Trigger full reload for all connected clients after initial build
          Log.info { "LiveReload: Initial build complete, triggering reload for all connected clients" }
          live_reload.send_reload(path: "/index.html", liveCSS: false)
          # Then run in auto mode
          Croupier::TaskManager.auto_run(arguments) # FIXME: check options
          loop do
            ::sleep(1.second)
          end
        rescue ex : Exception
          Log.error(exception: ex) { "Error running in auto mode: #{ex.message}" }
          Log.debug { ex.backtrace.join("\n") }
          1
        end
      end
    end
  end
end

Nicolino::Commands::Auto.register
