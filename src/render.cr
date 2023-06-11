require "RSS"

module Render
  # Render given posts using given template
  #
  # posts is an Array of `Markdown::File`
  # config is a Hash used for template context
  # template is a compiled crustache template
  # if require_date is true, posts *must* have a date
  def self.render(posts, template, require_date = true)
    posts.each do |post|
      if require_date && post.date == nil
        Util.log("Error: #{post.@source} has no date")
        next
      end

      output = "output/#{post.@link}"
      render = ->{
        Util.log("    #{output}")
        Render.write(post.rendered, template, output)
      }

      name = "render #{output}"
      Croupier::Task.new(
        name: name,
        output: output,
        inputs: ["conf", post.@source, post.template],
        block: render
      )
    end
  end

  def self.render_rss(posts, title, output)
    inputs = ["conf"] + posts.map { |post| post.@source }
    name = "render #{output}"

    render = ->{
      Util.log("    #{output}")
      feed = RSS.new title: title
      posts.each do |post|
        feed.item(
          title: post.@title,
          link: post.@link,
          pubDate: post.date.to_s
        )
      end
      Dir.mkdir_p(File.dirname output)
      File.open(output, "w") do |io|
        io.puts feed.xml indent: true
      end
    }

    Croupier::Task.new(
      name: name,
      output: output,
      inputs: inputs,
      block: render
    )
  end

  # Writes html, templated properly with config, into path
  def self.write(html, template, path)
    # TODO: use a copy of config
    rendered_page = Crustache.render(template,
      Config.config.merge({
        "content" => html,
      }))
    Dir.mkdir_p(File.dirname path)
    File.open(path, "w") do |io|
      io.puts rendered_page
    end
  end
end
