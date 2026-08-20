# Posts helper module for enabling blog posts feature
# This module coordinates reading and processing blog posts from multiple sources

require "./markdown"
require "./similarity"
require "./rss"

module Posts
  # Return glob patterns for posts content
  # Posts live in content/posts/ and support markdown, html, and pandoc formats
  def self.content_globs : Array(String)
    Utils.content_globs(Path[Config.options.content] / Config.options.posts)
  end

  # Create a file object from source files
  def self.create_file(sources : Hash(String, String), base : Path) : Markdown::File?
    Utils.create_content_file(sources, base, "post")
  end

  # Enable posts feature using pre-scanned files
  # Returns nil if posts feature is disabled
  def self.enable_from_scan(scan_result : Array(Markdown::File)?, feature_set : Set(YAML::Any)) : Array(Markdown::File)?
    return unless scan_result

    posts = scan_result
    features = feature_set.map(&.as_s).to_set

    Log.info { "✓ Found #{posts.size} post#{posts.size == 1 ? "" : "s"}" }

    # Calculate MinHash signatures for similarity feature
    # This must happen before rendering so related_posts are available
    if features.includes?("similarity")
      Similarity.create_tasks(posts)
    end

    # Render posts with require_date = true and require_title = true
    Markdown.render(posts, require_date: true, require_title: true)

    # Render RSS feeds for each language (only 20 most recent posts)
    Config.languages.keys.each do |lang|
      # Language suffix for non-English feeds
      lang_suffix = Utils.lang_suffix(lang)
      rss_output = Path[Config.output] / "rss#{lang_suffix}.xml"

      # Get language-specific site title
      site_title = Config[lang].title

      # RSS task now depends on post source files instead of rendered HTML
      RSSFeed.render(
        posts,
        rss_output,
        site_title,
        lang: lang,
      )
    end
    posts
  end
end
