# Posts helper module for enabling blog posts feature
# This module coordinates reading and processing blog posts from multiple sources

require "./markdown"
require "./html"
require "./pandoc"
require "./similarity"
require "./creatable"
require "./rss"

module Posts
  # Enable posts feature and return array of posts for dependent features
  # Returns nil if posts feature is disabled
  def self.enable(is_enabled : Bool, content_post_path : Path, feature_set : Set(Totem::Any)) : Array(Markdown::File)?
    return nil unless is_enabled

    Log.info { "📖 Scanning for posts..." }

    # Note: Posts are already registered by nicolino new command,
    # but features can register additional types here if needed
    # Convert Totem::Any set to string set for easier use
    features = feature_set.map(&.as_s).to_set

    # Read posts from multiple sources
    posts = Markdown.read_all(content_post_path)
    posts += HTML.read_all(content_post_path)
    posts += Pandoc.read_all(content_post_path) if features.includes?("pandoc")

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
      lang_suffix = lang == "en" ? "" : ".#{lang}"
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
