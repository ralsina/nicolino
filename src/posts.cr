# Posts helper module for enabling blog posts feature
# This module coordinates reading and processing blog posts from multiple sources

require "./markdown"
require "./html"
require "./pandoc"
require "./similarity"
require "./creatable"

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

    # Load dates for all posts before sorting (dates are lazy-loaded)
    # Use parallel processing to speed up date parsing (4 workers)
    t1 = Time.instant
    num_workers = 4
    channel = Channel(Markdown::File).new
    posts_per_worker = (posts.size / num_workers).ceil.to_i

    num_workers.times do
      spawn do
        while post = channel.receive?
          post.date
        end
      end
    end

    posts.each { |post| channel.send(post) }
    num_workers.times { channel.close }
    t2 = Time.instant

    posts.sort!
    t3 = Time.instant

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
      rss_output = Path[Config.options(lang).output] / "rss#{lang_suffix}.xml"

      # Get language-specific site title
      site_title = begin
        Config.languages[lang].as_h["site"].as_h["title"].as_s
      rescue
        Config.get("site.title").as_s
      end

      # Limit RSS to 20 most recent posts
      rss_posts = posts.first(20)

      Markdown.render_rss(
        rss_posts,
        rss_output,
        site_title,
        lang: lang,
      )
    end
    pp! Time.instant - t3
    pp! t3 - t2
    pp! t2 - t1

    posts
  end
end
