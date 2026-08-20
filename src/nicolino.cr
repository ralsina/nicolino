require "./assets"
require "./archive"
require "./creatable"
require "./commands/*"
require "./base16"
require "./content_scanner"
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
require "./template_preprocessor"
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

  # Parallel content scanning: posts first, then pages (priority order)
  if features.includes?("posts") || features.includes?("pages")
    Log.info { "📖 Scanning content..." }
    scan_start = Time.instant

    # Build feature list in priority order (galleries before pages)
    content_features = [] of NamedTuple(name: String, globs: Array(String), create_file: Hash(String, String), Path -> Markdown::File?)
    content_features << {name: "posts", globs: Posts.content_globs, create_file: ->Posts.create_file(Hash(String, String), Path)}
    content_features << {name: "galleries", globs: Gallery.content_globs, create_file: ->Gallery.create_file(Hash(String, String), Path)}
    content_features << {name: "pages", globs: Pages.content_globs, create_file: ->Pages.create_file(Hash(String, String), Path)}

    # Single parallel scan
    scan_results = ContentScanner.scan_all(content_features)
    scan_elapsed = Time.instant - scan_start
    Log.info { "✓ Content scan completed in #{scan_elapsed.total_milliseconds}ms" }

    # Enable posts from scan results
    posts = nil
    if features.includes?("posts")
      posts = time_feature_enable("posts") { Posts.enable_from_scan(scan_results["posts"]?, features) }
    end

    time_feature_enable("taxonomies") { Taxonomies.enable(features.includes?("taxonomies"), posts) } if posts
    time_feature_enable("archive") { Archive.enable(features.includes?("archive"), posts) } if posts

    # Enable galleries from scan results
    time_feature_enable("galleries") { Gallery.enable_from_scan(scan_results["galleries"]?, features) }

    # Enable pages from scan results
    time_feature_enable("pages") { Pages.enable_from_scan(scan_results["pages"]?, features) }
  else
    # No content features enabled, but still need to handle other features
    posts = nil
  end

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
  # Shortcode render failures are recorded per-run (see Sc.render_sc);
  # start each run with a clean slate
  Sc.reset_failures
  # Run tasks for real
  Log.info { "Running tasks..." }
  Log.debug { "About to call run_tasks with #{Croupier::TaskManager.tasks.size} tasks" }
  start_time = Time.instant
  Croupier::TaskManager.run_tasks(
    targets: arguments,
    parallel: parallel,
    keep_going: keep_going,
    dry_run: dry_run,
    run_all: run_all,
  )
  elapsed = (Time.instant - start_time).total_milliseconds
  Log.debug { "run_tasks took #{elapsed}ms" }

  # Per-page profiling breakdown
  Log.info { "  ⏱  Per-page breakdown:" }
  Markdown::Profiler.report

  # Generate feature timing report
  FeatureTiming.report

  # A failed shortcode render degrades that page silently; fail the
  # whole build loudly instead of publishing corrupted output
  failures = Sc.render_failures
  unless failures.empty?
    Log.error { "🏁 Done with #{failures.size} shortcode rendering failure(s):" }
    failures.each do |failure|
      Log.error { "  #{failure[:shortcode]}: #{failure[:error]}" }
    end
    return 1
  end

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
