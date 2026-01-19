require "./assets"
require "./archive"
require "./commands/*"
require "./base16"
require "./books"
require "./config"
require "./gallery"
require "./html"
require "./http_handlers"
require "./image"
require "./folder_indexes"
require "./listings"
require "./locale"
require "./markdown"
require "./pandoc"
require "./render"
require "./sc"
require "./search"
require "./sitemap"
require "./similarity"
require "./taxonomies"
require "./template"
require "./theme_assets"
require "croupier"
require "live_reload"
require "yaml"

VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

def create_tasks
  # Load config file
  features = Set.new(Config.get("features").as_a)

  content_path = Path[Config.options.content]
  content_post_path = content_path / Config.options.posts
  galleries_path = content_path / Config.options.galleries

  # Check for required external commands
  Pandoc.enable(features.includes?("pandoc"))

  # Load templates to k/v store
  Templates.load_templates

  # Load shortcodes to k/v store
  Sc.load_shortcodes

  # Copy theme assets (always enabled)
  ThemeAssets.enable

  # Enable features
  Assets.enable(features.includes?("assets"))
  Base16.enable(features.includes?("base16"))

  # Posts must be enabled before taxonomies, archive, and similarity
  posts = Posts.enable(features.includes?("posts"), content_post_path, features)

  Taxonomies.enable(features.includes?("taxonomies"), posts) if posts
  Similarity.enable(features.includes?("similarity"), posts) if posts
  Archive.enable(features.includes?("archive"), posts) if posts

  Gallery.enable(features.includes?("galleries"), galleries_path)
  Pages.enable(features.includes?("pages"), content_path, features)
  Image.enable(features.includes?("images"), content_path)
  Listings.enable(features.includes?("listings"), content_path)
  Books.enable(features.includes?("books"))
  Sitemap.enable(features.includes?("sitemap"))
  Search.enable(features.includes?("search"))
  FolderIndexes.enable(features.includes?("folder_indexes"), content_path)
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
