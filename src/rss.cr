require "RSS"

module RSSFeed
  # Create a RSS feed task
  # This creates a task that generates an RSS feed from posts
  # max_items: maximum number of posts to include in the feed (default 20)
  def self.render(posts, output, title, lang = nil, feature_name = "posts", max_items : Int32 = 20)
    lang ||= Locale.language
    # The feed renders each post's summary, which processes
    # shortcodes, so the shortcode templates must be declared
    # inputs or parallel builds race against the kv tasks
    inputs = ["conf.yml"] + posts.map(&.source) +
             posts.flat_map(&.shortcode_dependencies(lang))

    FeatureTask.new(
      feature_name: feature_name,
      id: "rss",
      output: output.to_s,
      inputs: inputs,
      mergeable: false
    ) do
      feed = RSS.new title: title
      posts
        .select { |post| !post.date.nil? }
        # Output path tiebreaker: content reading is parallel, so the
        # input order of same-date posts is not stable. All selected
        # posts have dates, so coalescing never kicks in
        .sort_by! { |post| {post.date || Time.unix(0), post.output} }
        .last(max_items)
        .reverse!
        .each do |post|
          feed.item(
            title: post.title(lang),
            description: post.summary(lang),
            link: post.link(lang),
            pubDate: post.date.to_s,
          )
        end
      feed.xml indent: true
    end
  end
end
