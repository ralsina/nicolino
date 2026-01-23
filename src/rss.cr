require "RSS"

module RSSFeed
  # Create a RSS feed task
  # This creates a task that generates an RSS feed from posts
  # max_items: maximum number of posts to include in the feed (default 20)
  def self.render(posts, output, title, lang = nil, feature_name = "posts", max_items : Int32 = 20)
    lang ||= Locale.language
    inputs = ["conf.yml"] + posts.map(&.source)

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
        .sort_by! { |post| post.date.as(Time) }
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
