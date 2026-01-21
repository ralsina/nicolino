require "./markdown"
require "./theme"

module FolderIndexes
  # Registry for feature modules to register their output folders
  # that should be excluded from automatic index generation
  @@excluded_folders = [] of String

  def self.register_exclude(folder : String)
    @@excluded_folders << folder unless @@excluded_folders.includes?(folder)
  end

  def self.excluded_folders
    @@excluded_folders
  end

  # Directories that generate their own indexes (excluded from folder_indexes)
  # Pages now handles page directories, so we exclude those too
  DEFAULT_EXCLUDED = ["galleries", "listings", "books", "pages"]

  # Enable folder_indexes feature
  # This now ONLY handles posts/ folder and subfolders
  def self.enable(is_enabled : Bool, content_path : Path)
    return unless is_enabled

    Log.info { "📁 Scanning for posts folder indexes..." }

    # Collect exclude patterns from two sources:
    # 1. Config file (manual overrides)
    # 2. Feature modules that register their output folders
    # 3. Default exclusions (features that handle their own indexes)

    exclude_patterns = [] of String

    # 1. Get exclude patterns from config if available
    begin
      exclude_dirs = Config.get("folder_indexes.exclude_dirs")
      exclude_patterns = exclude_dirs.as_a.map(&.as_s) if exclude_dirs
    rescue
      # Key doesn't exist, use empty array
    end

    # 2. Get registered exclusions from feature modules
    exclude_patterns += excluded_folders

    # 3. Add default exclusions for features that handle their own indexes
    exclude_patterns += DEFAULT_EXCLUDED

    # Scan posts path for folders needing indexes
    content_path = content_path.expand
    posts_path = content_path / Config.options.posts
    indexes = read_all(posts_path, exclude_patterns)
    Log.info { "✓ Found #{indexes.size} posts folder index#{indexes.size == 1 ? "" : "es"}" }
    render(indexes)
  end

  # Generates indexes for posts folders that have no index file
  struct FolderIndex
    @path : Path
    @output : Path

    def initialize(path : Path)
      @path = path
      # Get the relative path from posts directory
      posts_path = Path.new(Config.options.content).expand / Config.options.posts
      @output = (path / "index.html").relative_to(posts_path)
    end

    # Get all posts whose output starts with this folder's path (prefix-matching)
    def posts_by_prefix(lang : String? = nil)
      lang ||= Locale.language
      content_path = Path.new(Config.options.content).expand
      output_prefix = Config.options.output.rchop('/')
      output_folder = "#{output_prefix}/#{@path.relative_to(content_path)}"

      # Find all posts whose output path starts with this folder
      Markdown::File.posts.values.select do |post|
        post.output(lang).starts_with?(output_folder)
      end.sort_by! { |post_data| post_data.date || Time.utc(1970, 1, 1) }.reverse!
    end

    # Get the title for this folder index
    def folder_title
      @path.basename.to_s.capitalize
    end

    # Get breadcrumbs for this folder index
    def breadcrumbs
      content_path = Path.new(Config.options.content).expand
      folder_relative = @path.relative_to(content_path)

      result = [{name: "Home", link: "/"}] of NamedTuple(name: String, link: String)

      # Build breadcrumbs for intermediate folders (if any)
      current_path = Path.new(".")
      folder_relative.parts[0..-2].each do |part|
        current_path = current_path / part
        # Build the full output path for this breadcrumb
        full_path = Path[Config.options.output] / current_path / "index.html"
        result << {
          name: part,
          link: Utils.path_to_link(full_path),
        }
      end

      # Add current folder as the last breadcrumb (with link to itself)
      result << {
        name: @path.basename.to_s.capitalize,
        link: Utils.path_to_link(Path[Config.options.output] / @output),
      }

      result
    end
  end

  def self.read_all(posts_path : Path, exclude_patterns = [] of String) : Array(FolderIndex)
    indexes = [] of FolderIndex
    candidates = [posts_path] + Dir.glob("#{posts_path}/**/*/")

    candidates.map do |folder|
      # Skip if folder matches any exclude pattern
      next if exclude_patterns.any? { |pattern| folder.to_s.includes?(pattern) }

      # Create a temporary FolderIndex to check the expected output path
      temp_index = FolderIndex.new(Path.new(folder))

      # Check if any task already produces this folder's index.html
      expected_output = Path[Config.options.output] / temp_index.@output
      has_task_for_output = Croupier::TaskManager.tasks.values.any? do |task|
        task.outputs.includes?(expected_output.to_s)
      end

      # Check if there's a .noindex file to exclude this folder
      has_noindex = File.file?("#{folder}/.noindex")

      # Only generate folder index if no task produces this output and no .noindex file
      if has_task_for_output
        Log.debug { "Skipping #{folder}: index.html already produced by another task" }
      elsif has_noindex
        Log.debug { "Skipping #{folder}: .noindex found" }
      else
        Log.debug { "👈 #{folder}" }
        indexes << temp_index
      end
    end
    indexes
  end

  def self.render(indexes : Array(FolderIndex))
    Config.languages.keys.each do |lang|
      out_path = Path.new(Config.options(lang).output)
      lang_suffix = lang == "en" ? "" : ".#{lang}"

      # Render posts folders using Markdown.render_index
      indexes.each do |index|
        folder_posts = index.posts_by_prefix(lang)
        next if folder_posts.empty?

        # Add language suffix to output path
        output_path = index.@output.to_s.sub(/\.html$/, "#{lang_suffix}.html")
        output = (out_path / output_path).to_s
        title = index.folder_title

        # Create RSS feed for this folder
        feed_path = output.sub(/\.html$/, ".rss")
        feed_title = "#{title} - RSS"

        Markdown.render_rss(
          folder_posts[..10],
          feed_path,
          feed_title,
          lang: lang,
        )

        Markdown.render_index(
          folder_posts,
          output,
          title,
          extra_feed: {link: Utils.path_to_link(feed_path), title: feed_title},
          main_feed: nil, # Folder indexes don't get main feed
          lang: lang,
        )
      end
    end
  end
end
