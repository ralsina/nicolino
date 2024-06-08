def validate(options, arguments)
  load_config(options)
  features = Set.new(Config.get("features").as_a)
  content_path = Path[Config.options.content]
  content_post_path = content_path / Config.options.posts

  error_count = 0
  if features.includes? "posts"
    posts = Markdown.read_all(content_post_path)
    posts += HTML.read_all(content_post_path)
    posts += Pandoc.read_all(content_post_path) if features.includes? "pandoc"
    if !posts.nil?
      error_count += Markdown.validate(posts, require_date: true)
    end
  end

  if features.includes? "pages"
    pages = Markdown.read_all(content_path)
    pages += HTML.read_all(content_path)
    pages += Pandoc.read_all(content_path) if features.includes? "pandoc"
    if !pages.nil?
      error_count += Markdown.validate(pages, require_date: false)
    end
  end
  return unless error_count > 0
  Log.error { "Validation failed with #{error_count} errors" }
  1
end
