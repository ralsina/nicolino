# Nicolino, a basic static site generator.

require "./assets"
require "./config"
require "./http_handlers"
require "./image"
require "./markdown"
require "./render"
require "./template"
require "croupier"
require "live_reload"
require "yaml"

VERSION = "0.1.0"

def create_tasks
  # Load config file
  Config.config

  # Load templates to k/v store
  Templates.load_templates

  # Copy assets/ to output/
  Assets.render

  # Render posts and RSS feed
  posts = Markdown::File.read_all("posts/")
  Render.render(posts, require_date: true)

  Render.render_rss(
    posts[..10],
    Config.config["title"].to_s,
    "output/rss.xml"
  )

  Render.render_index(
    posts[..10],
    "output/index.html"
  )

  # Render pages
  pages = Markdown::File.read_all("pages/")
  Render.render(pages, require_date: false)

  # Render images
  images = Image.read_all("posts/") + Image.read_all("pages/")
  Image.render(images)
end

def run(options, arguments)
  create_tasks
  Croupier::TaskManager.fast_mode = options.bool.fetch("fastmode", false)

  arguments = Croupier::TaskManager.tasks.keys if arguments.empty?
  # Run tasks for real
  Log.info { "Running tasks..." }
  Croupier::TaskManager.run_tasks(
    targets: arguments,
    parallel: options.bool.fetch("parallel", false),
    keep_going: options.bool.fetch("keep_going", false),
    dry_run: options.bool.fetch("dry_run", false),
    run_all: options.bool.fetch("run_all", false),
  )
  Log.info { "Done!" }
  0
end

# Run forever automatically rebuilding the site
def auto(options, arguments)
  create_tasks
  Croupier::TaskManager.fast_mode = options.bool.fetch("fastmode", false)

  # Now run in auto mode
  begin
    Log.info { "Running in auto mode, press Ctrl+C to stop" }
    # Launch HTTP server
    spawn do
      serve(options, arguments, live_reload: true)
    end

    # Launch LiveReload server
    live_reload = LiveReload::Server.new
    Log.info { "LiveReload on http://#{live_reload.address}" }
    spawn do
      live_reload.listen
    end

    # Create task that will be triggered in rebuilds
    Croupier::Task.new(
      id: "LiveReload",
      inputs: Croupier::TaskManager.tasks.keys,
      proc: Croupier::TaskProc.new {
        Croupier::TaskManager.modified.each do |path|
          next if path.lchop? "kv://"
          path = path.lchop "output"
          Log.info { "LiveReload: #{path}" }
          live_reload.send_reload(path: path, liveCSS: path.ends_with?(".css"))
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
    return 1
  end
  loop do
    sleep 1
  end
  0
end

def serve(options, arguments, live_reload = false)
  handlers = [
    Handler::LiveReloadHandler.new,
    Handler::IndexHandler.new,
    HTTP::StaticFileHandler.new("output"),
  ]

  handlers.delete_at(0) if !live_reload

  server = HTTP::Server.new handlers
  address = server.bind_tcp 8080
  Log.info { "Server listening on http://#{address}" }
  server.listen
end
