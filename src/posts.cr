# Posts helper module for enabling blog posts feature
# This module coordinates reading and processing blog posts from multiple sources

require "./markdown"
require "./html"
require "./pandoc"
require "./similarity"

module Posts
  # Enable posts feature and return array of posts for dependent features
  # Returns nil if posts feature is disabled
  def self.enable(is_enabled : Bool, content_post_path : Path, feature_set : Set(Totem::Any)) : Array(Markdown::File)?
    return nil unless is_enabled

    # Convert Totem::Any set to string set for easier use
    features = feature_set.map(&.as_s).to_set

    # Read posts from multiple sources
    posts = Markdown.read_all(content_post_path)
    posts += HTML.read_all(content_post_path)
    posts += Pandoc.read_all(content_post_path) if features.includes?("pandoc")
    posts.sort!

    # Calculate MinHash signatures for similarity feature
    # This must happen before rendering so related_posts are available
    if features.includes?("similarity")
      Similarity.create_tasks(posts)
    end

    # Render posts with require_date = true
    Markdown.render(posts, require_date: true)

    # Render RSS feed
    rss_output = Path[Config.options.output] / "rss.xml"
    site_title = Config.get("site.title").as_s
    Markdown.render_rss(
      posts[..10],
      rss_output,
      site_title,
    )

    posts
  end
end
