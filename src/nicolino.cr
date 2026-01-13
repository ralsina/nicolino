require "./assets"
require "./archive"
require "./commands/*"
require "./base16"
require "./config"
require "./gallery"
require "./html"
require "./http_handlers"
require "./image"
require "./folder_indexes"
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

VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

def create_tasks # ameba:disable Metrics/CyclomaticComplexity
  # Load config file
  features = Set.new(Config.get("features").as_a)

  output_path = Path[Config.options.output]
  content_path = Path[Config.options.content]
  content_post_path = content_path / Config.options.posts
  content_post_output_path = output_path / Config.options.posts
  galleries_path = content_path / Config.options.galleries

  # Check for required external commands
  if features.includes? "pandoc"
    unless `which pandoc`.strip.empty? == false
      Log.error { "The 'pandoc' feature is enabled but pandoc is not installed or not in PATH" }
      Log.error { "Please install pandoc or disable the 'pandoc' feature in conf.yml" }
      exit 1
    end
  end

  # Load templates to k/v store
  Templates.load_templates

  # Load shortcodes to k/v store
  Sc.load_shortcodes

  # Copy assets/ to output/
  if features.includes? "assets"
    Assets.render
  end

  # Render custom color scheme
  if features.includes? "base16"
    Base16.render_base16
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
        Log.debug { "Scanning taxonomy: #{k}" }
        Taxonomies::Taxonomy.new(
          k,
          v.title,
          v.term_title,
          v.location,
          posts
        ).render
      end
    end

    if features.includes? "archive"
      Archive.render(posts)
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

  if features.includes? "galleries"
    # Render galleries
    galleries = Gallery.read_all(galleries_path)
    Gallery.render(galleries, Config.options.galleries)
  end

  # Render pages last because it's a catchall and will find gallery
  # posts, blog posts, etc.
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

  # Render sitemap
  if features.includes? "sitemap"
    Sitemap.render
  end

  # Render search data
  if features.includes? "search"
    Search.render
  end

  # Make indexes for other folders without a index.* file
  # TODO: enable for other places once we have a way to handle conflicts
  return unless features.includes? "folder_indexes"

  # Get exclude patterns from config if available
  exclude_patterns = [] of String
  begin
    exclude_dirs = Config.get("folder_indexes.exclude_dirs")
    exclude_patterns = exclude_dirs.as_a.map(&.as_s) if exclude_dirs
  rescue
    # Key doesn't exist, use empty array
  end

  # Automatically exclude galleries directory if galleries feature is enabled
  # to avoid conflicts with gallery index generation
  if features.includes? "galleries"
    galleries_exclude = Config.options.galleries
    exclude_patterns << galleries_exclude unless exclude_patterns.includes?(galleries_exclude)
  end

  indexes = FolderIndexes.read_all(galleries_path, exclude_patterns)
  FolderIndexes.render(indexes)
end

def run(
  arguments : Array(String),
  parallel = false,
  keep_going = false,
  dry_run = false,
  run_all = false,
  fast_mode = false,
)
  # When doing auto() this is called twice, no need to scan tasks
  # twice
  if Croupier::TaskManager.tasks.empty?
    Croupier::TaskManager.use_persistent_store(".kvstore")
    create_tasks
    Croupier::TaskManager.fast_mode = fast_mode
  end

  # Pre-create all output directories for better performance
  create_all_directories

  arguments = Croupier::TaskManager.tasks.keys if arguments.empty?
  # Run tasks for real
  Log.info { "Running tasks..." }
  Croupier::TaskManager.run_tasks(
    targets: arguments,
    parallel: parallel,
    keep_going: keep_going,
    dry_run: dry_run,
    run_all: run_all,
  )
  Log.info { "🏁 Done!" }
  0
end

def create_all_directories
  Log.debug { "Pre-creating all output directories..." }
  directories = Set(String).new

  # Collect all unique parent directories from task outputs
  Croupier::TaskManager.tasks.each do |task_id, task|
    # For image processing tasks, we need parent directories of outputs
    if task_id.starts_with?("image:") || task_id.starts_with?("thumb:")
      task.outputs.each do |output|
        directories.add(Path[output].parent.to_s)
      end
    else
      # For other files, get parent directory
      task.outputs.each do |output|
        directories.add(Path[output].parent.to_s)
      end
    end
  end

  # Create all directories in one pass
  directories.each do |dir|
    Dir.mkdir_p(dir)
  end

  Log.debug { "Created #{directories.size} directories" }
end
