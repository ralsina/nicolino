require "./assets"
require "./archive"
require "./creatable"
require "./commands/*"
require "./base16"
require "./feature_timing"
require "./books"
require "./config"
require "./gallery"
require "./html"
require "./http_handlers"
require "./image"
require "./folder_indexes"
require "./pages"
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

# Helper to time feature enable calls
def time_feature_enable(name : String, &)
  start = Time.instant
  result = yield
  elapsed = Time.instant - start
  FeatureTiming.record_enable(name, elapsed)
  result
end

def create_tasks
  # Load config file
  Log.info { "⚙️  Loading configuration..." }
  features = Config.features_set

  content_path = Path[Config.options.content]
  content_post_path = content_path / Config.options.posts
  galleries_path = content_path / Config.options.galleries
  Log.info { "✓ Configuration loaded" }

  # Check for required external commands
  Log.info { "🔍 Checking external commands..." }
  Pandoc.enable(features.includes?("pandoc"))
  Log.info { "✓ External commands checked" }

  # Load templates to k/v store
  Log.info { "📋 Loading templates..." }
  template_count = Templates.load_templates
  Log.info { "✓ Loaded #{template_count} template#{template_count == 1 ? "" : "s"}" }

  # Load shortcodes to k/v store
  Log.info { "📝 Loading shortcodes..." }
  shortcode_count = Sc.load_shortcodes
  Log.info { "✓ Loaded #{shortcode_count} shortcode#{shortcode_count == 1 ? "" : "s"}" }

  # Copy theme assets (always enabled)
  Log.info { "🎨 Copying theme assets..." }
  ThemeAssets.enable
  Log.info { "✓ Theme assets copied" }

  # Enable features
  Log.info { "🚀 Enabling features..." }
  time_feature_enable("assets") { Assets.enable(features.includes?("assets")) }
  time_feature_enable("base16") { Base16.enable(features.includes?("base16")) }

  # Posts must be enabled before taxonomies, archive, and similarity
  posts = time_feature_enable("posts") { Posts.enable(features.includes?("posts"), content_post_path, features) }

  time_feature_enable("taxonomies") { Taxonomies.enable(features.includes?("taxonomies"), posts) } if posts
  time_feature_enable("similarity") { Similarity.enable(features.includes?("similarity"), posts) } if posts
  time_feature_enable("archive") { Archive.enable(features.includes?("archive"), posts) } if posts

  time_feature_enable("galleries") { Gallery.enable(features.includes?("galleries"), galleries_path) }
  time_feature_enable("pages") { Pages.enable(features.includes?("pages"), content_path, features) }
  time_feature_enable("images") { Image.enable(features.includes?("images"), content_path) }
  time_feature_enable("listings") { Listings.enable(features.includes?("listings"), content_path) }
  time_feature_enable("books") { Books.enable(features.includes?("books")) }
  time_feature_enable("sitemap") { Sitemap.enable(features.includes?("sitemap")) }
  time_feature_enable("search") { Search.enable(features.includes?("search")) }
  time_feature_enable("folder_indexes") { FolderIndexes.enable(features.includes?("folder_indexes"), content_path) }
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
  Log.info { "[DEBUG] About to call run_tasks with #{Croupier::TaskManager.tasks.size} tasks" }
  start_time = Time.instant
  Croupier::TaskManager.run_tasks(
    targets: arguments,
    parallel: parallel,
    keep_going: keep_going,
    dry_run: dry_run,
    run_all: run_all,
  )
  elapsed = (Time.instant - start_time).total_milliseconds
  Log.info { "[DEBUG] run_tasks took #{elapsed}ms" }

  # Generate feature timing report
  FeatureTiming.report

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
