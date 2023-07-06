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
        Log.info { "Error: #{post.@source} has no date" }
        next
      end

      output = "output/#{post.@link}"
      Croupier::Task.new(
        output: output,
        inputs: ["conf", post.@source, post.template],
        proc: Croupier::TaskProc.new {
          Log.info { ">> #{output}" }
          apply_template(post.rendered, template)
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

  # Generates HTML properly templated
  def self.apply_template(html, template)
    # TODO: use a copy of config
    Crustache.render(template,
      Config.config.merge({
        "content" => html,
      }))
  end
end
