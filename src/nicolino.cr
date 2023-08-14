# Nicolino, a basic static site generator.

require "./assets"
require "./config"
require "./gallery"
require "./html"
require "./http_handlers"
require "./image"
require "./locale"
require "./markdown"
require "./pandoc"
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
  features = Set.new(Config.get("features").as_a)

  output_path = Path[Config.options.output]
  content_path = Path[Config.options.content]
  content_post_path = content_path / Config.options.posts
  content_post_output_path = output_path / Config.options.posts
  galleries_path = content_path / Config.options.galleries

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
    # FIXME: use a compiler registry or something
    posts = Markdown.read_all(content_post_path)
    posts += HTML.read_all(content_post_path)
    posts += Pandoc.read_all(content_post_path) if features.includes? "pandoc"
    Markdown.render(posts, require_date: true)
    posts.sort!

    if features.includes? "taxonomies"
      Config.taxonomies.map do |k, v|
        Log.info { "Scanning taxonomy: #{k}" }
        Taxonomies::Taxonomy.new(
          k,
          v.title,
          v.term_title,
          v.location,
          posts
        ).render
      end
    end

    Markdown.render_rss(
      posts[..10],
      Path[Config.options.output] / "rss.xml",
      Config.get("site.title").as_s,
    )

    Markdown.render_index(
      posts[..10],
      content_post_output_path / "index.html",
      title: "Latest posts"
    )
  end

  # Render pages
  if features.includes? "pages"
    pages = Markdown.read_all(content_path)
    pages += HTML.read_all(content_path)
    pages += Pandoc.read_all(content_path) if features.includes? "pandoc"
    Markdown.render(pages, require_date: false)
  end

  # Render images from content
  if features.includes? "images"
    images = Image.read_all(content_path)
    Image.render(images)
  end

  if features.includes? "galleries"
    # Render galleries
    galleries = Gallery.read_all(galleries_path)
    Gallery.render(galleries, Config.options.galleries)
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
  make_server(options, arguments, live_reload).listen
end

def clean(options, arguments)
  create_tasks
  existing = Set.new(Dir.glob(Path[Config.options.output] / "**/*"))
  targets = Set.new(Croupier::TaskManager.tasks.keys)
  targets = targets.map { |p| Path[p].normalize.to_s }
  to_clean = existing - targets
  # Only delete files
  to_clean.each do |p|
    next if File.info(p).directory?
    Log.warn { "❌ #{p}" }
    File.delete(p)
  end
end

def new(options, arguments)
  paths = arguments.map { |a| Path[a] }
  paths.each do |p|
    raise "Can't create #{p}, new is used to create data inside #{Config.options.content}" \
       if p.parts[0] != Config.options.content.rstrip("/")

    # So, we want to create output/whatever/foo
    # What kind of whatever, if any, is it?

    if p.parts.size < 3
      kind = "page"
    else
      # FIXME: This could be generalized so it works with more than one level
      # of subdirectory, so galleries could be in content/image/galleries
      kind = {
        Config.options.galleries.rstrip("/") => "gallery",
        Config.options.posts.rstrip("/")     => "post",
      }.fetch(p.parts[1], "page")
    end
    # Call the proper module's content generator with the path
    if kind == "post"
      Markdown.new_post p
    elsif kind == "gallery"
      Gallery.new_gallery p
    else
      Markdown.new_page p
    end
  end
end
