require "RSS"

module Render
  # Render given posts using given template
  #
  # posts is an Array of `Markdown::File`
  # config is a Hash used for template context
  # if require_date is true, posts *must* have a date
  def self.render(posts, require_date = true)
    posts.each do |post|
      if require_date && post.date == nil
        Log.info { "Error: #{post.@source} has no date" }
        next
      end

      output = "output/#{post.@link}"
      Croupier::Task.new(
        output: output,
        inputs: ["conf", post.@source, "kv://#{post.template}", "kv://templates/page.tmpl"],
        proc: Croupier::TaskProc.new {
          Log.info { ">> #{output}" }
          apply_template(post.rendered, "templates/page.tmpl")
        }
      )
    end
  end

  def self.render_rss(posts, title, output)
    inputs = ["conf"] + posts.map { |post| post.@source }

    Croupier::Task.new(
      output: output,
      inputs: inputs,
      proc: Croupier::TaskProc.new {
        Log.info { ">> #{output}" }
        feed = RSS.new title: title
        posts.each do |post|
          feed.item(
            title: post.@title,
            link: post.@link,
            pubDate: post.date.to_s
          )
        end
        feed.xml indent: true
      }
    )
  end

  def self.render_index(posts, output)
    inputs = ["conf", "kv://templates/index.tmpl"] + posts.map { |post| post.@source } + posts.map { |post| post.template }
    inputs = inputs.uniq
    Croupier::Task.new(
      output: output,
      inputs: inputs,
      proc: Croupier::TaskProc.new {
        Log.info { ">> #{output}" }
        content = Templates::Env.get_template("templates/index.tmpl").render({"posts" => posts.map(&.value)})
        apply_template(content, "templates/page.tmpl")
      }
    )
  end

  # Generates HTML properly templated
  def self.apply_template(html, template)
    # TODO: use a copy of config
    Templates::Env.get_template(template).render(
      Config.config.merge({
        "content" => html,
      }))
  end
end
