def new(options, arguments)
  load_config(options)
  paths = arguments.map { |a| Path[a] }
  paths.each do |p|
    raise "Can't create #{p}, new is used to create data inside #{Config.options.content}" \
      if p.parts[0] != Config.options.content.rstrip("/")

    # So, we want to create output/whatever/foo
    # What kind of whatever, if any, is it?

    if p.parts.size < 3
      kind = "page"
    else
      # FIXME: This could be generalized so it works with more than one level
      # of subdirectory, so galleries could be in content/image/galleries
      kind = {
        Config.options.galleries.rstrip("/") => "gallery",
        Config.options.posts.rstrip("/")     => "post",
      }.fetch(p.parts[1], "page")
    end
    # Call the proper module's content generator with the path
    if kind == "post"
      Markdown.new_post p
    elsif kind == "gallery"
      Gallery.new_gallery p
    else
      Markdown.new_page p
    end
  end
end
