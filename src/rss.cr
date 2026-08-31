require "RSS"
require "lexbor"
require "./html_filters"

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
      # Absolute URLs for everything: readers see the feed out of
      # context, so relative links break. post.link already carries
      # the url_prefix, so site + link is the public URL even for
      # sites served under a subpath.
      site = Config[lang].url.chomp("/")
      feed = RSS.new title: title, site_url: site, language: lang
      posts
        .select(&.has_language?(lang))
        .select { |post| !post.date.nil? }
        # Output path tiebreaker: content reading is parallel, so the
        # input order of same-date posts is not stable. All selected
        # posts have dates, so coalescing never kicks in
        .sort_by! { |post| {post.date || Time.unix(0), post.output} }
        .last(max_items)
        .reverse!
        .each do |post|
          link = site + post.link(lang)
          summary = post.summary(lang)
          # First relativize exactly like the page render does, so the
          # html matches what a browser sees at the post's public URL
          # (markdown-relative paths ignore the url_prefix mount); then
          # absolutize against that public URL
          summary = if HtmlFilters.string_rewrite_safe?(summary)
                      HtmlFilters.relativize_links_in_string(summary, post.link(lang))
                    else
                      doc = HtmlFilters.make_links_relative(Lexbor::Parser.new(summary), post.link(lang))
                      HtmlFilters.fix_code_classes(doc).to_html
                    end
          if HtmlFilters.string_rewrite_safe?(summary)
            summary = HtmlFilters.absolutize_links_in_string(summary, link)
          else
            summary = HtmlFilters.make_links_absolute(Lexbor::Parser.new(summary), link).to_html
          end
          feed.item(
            title: post.title(lang),
            description: summary,
            link: link,
            pubDate: post.date.to_s,
          )
        end
      feed.xml indent: true
    end
  end
end
