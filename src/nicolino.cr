# Nicolino, a basic static site generator.

require "./assets"
require "./config"
require "./gallery"
require "./http_handlers"
require "./image"
require "./markdown"
require "./render"
require "./sc"
require "./search"
require "./sitemap"
require "./taxonomies"
require "./template"
require "croupier"
require "live_reload"
require "yaml"

VERSION = "0.1.0"

def create_tasks
  # Load config file
  Config.config
  # FIXME configure a default feature set
  features = Set.new(Config.config["features"].as_a)

  # Load templates to k/v store
  Templates.load_templates

  # Load shortcodes to k/v store
  Sc.load_shortcodes

  # Copy assets/ to output/
  if features.includes? "assets"
    Assets.render
  end

  # Render posts and RSS feed
  if features.includes? "posts"
    posts = Markdown.read_all("posts/")
    Markdown.render(posts, require_date: true)
    posts.sort!

    Config.config["taxonomies"].as_h.each do |k, v|
      Log.info { "Scanning taxonomy: #{k}" }
      Taxonomies::Taxonomy.new(
        k.as_s,
        v["title"].as_s,
        v["term_title"].as_s,
        "output/#{v["output"].as_s}",
        posts
      ).render
    end

    Markdown.render_rss(
      posts[..10],
      "output/rss.xml",
      Config.config["site_title"].to_s,
    )

    Markdown.render_index(
      posts[..10],
      "output/posts/index.html",
      title: "Latest posts"
    )
  end

  # Render pages
  if features.includes? "pages"
    pages = Markdown.read_all("pages/")
    Markdown.render(pages, require_date: false)
  end

  # Render images from posts and pages
  if features.includes? "images"
    images = Image.read_all("posts/") + Image.read_all("pages/")
    Image.render(images)
  end

  # Render images from galleries
  if features.includes? "galleries"
    images = Image.read_all("galleries/")
    Image.render(images, "galleries")

    # Render galleries
    galleries = Gallery.read_all("galleries/")
    Gallery.render(galleries, "galleries")
  end

  # Render sitemap
  if features.includes? "sitemap"
    Sitemap.render
  end

  # Render search data
  return unless features.includes? "search"
  Search.render
end

def run(options, arguments)
  # When doing auto() this is called twice, no need to scan tasks
  # twice
  if Croupier::TaskManager.tasks.empty?
    Croupier::TaskManager.use_persistent_store(".kvstore")
    create_tasks
    Croupier::TaskManager.fast_mode = options.bool.fetch("fastmode", false)
  end

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
      mergeable: false,
      proc: Croupier::TaskProc.new {
        modified = Set(String).new
        Croupier::TaskManager.modified.each do |path|
          next if path.lchop? "kv://"
          Croupier::TaskManager.depends_on(path).each do |p|
            p = p.lchop "output"
            modified << p
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
