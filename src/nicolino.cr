# Nicolino, a basic static site generator.

require "./assets"
require "./config"
require "./markdown"
require "./render"
require "./template"
require "croupier"
require "http/server"
require "yaml"

VERSION = "0.1.0"

def create_tasks
  # Load config file
  Config.config
  page_template = Templates::Template.get("templates/page.tmpl")

  # Copy assets/ to output/
  Assets.render

  # Render posts and RSS feed
  posts = Markdown::File.read_all("posts")
  Render.render(posts, page_template, require_date: true)

  Render.render_rss(
    posts[..10],
    Config.config["title"].to_s,
    "output/rss.xml"
  )

  # Render pages
  pages = Markdown::File.read_all("pages")
  Render.render(pages, page_template, require_date: false)
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

# Run forver automatically rebuilding the site
def auto(options, arguments)
  # First do a normal run
  arguments = Croupier::TaskManager.tasks.keys if arguments.empty?
  run(options, arguments)

  # Now run in auto mode
  begin
    Log.info { "Running in auto mode, press Ctrl+C to stop" }
    spawn do
      serve(options, arguments)
    end
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

def serve(options, arguments)
  server = HTTP::Server.new ([HTTP::StaticFileHandler.new("output")])
  address = server.bind_tcp 8080
  Log.info { "Server listening on http://#{address}" }
  server.listen
end
