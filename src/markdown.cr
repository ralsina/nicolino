require "./html_filters"
require "./sc"
require "cr-discount"
require "RSS"
require "shortcodes"

module Markdown
  # A class representing a Markdown file
  class File
    @date : Time | Nil
    @html : String = ""
    @link : String = ""
    @metadata = Hash(String, String).new
    @rendered : String = ""
    @shortcodes = Shortcodes::Result.new
    @source : String = ""
    @text : String = ""
    @title : String = ""
    @toc : String = ""

    # Register all Files by @source
    @@posts = Hash(String, File).new

    def self.posts
      @@posts
    end

    # Initialize the post with proper data
    def initialize(path)
      # TODO: lazy load data
      @source = path
      load
      @@posts[@source] = self
    end

    def <=>(other : File)
      # The natural sort order is date descending
      if self.@date.nil? || other.@date.nil?
        self.@title <=> other.@title
      else
        -1 * (self.@date.as(Time) <=> other.@date.as(Time))
      end
    end

    def to_s(io)
      io << "Post(#{@source})"
    end

    def load
      Log.info { "<< #{@source}" }
      contents = ::File.read(@source)
      _, metadata, @text = contents.split("---\n", 3)
      @metadata = YAML.parse(metadata).as_h.map { |k, v| [k.as_s.downcase.strip, v.to_s] }.to_h
      @title = @metadata["title"].to_s
      @link = "/" + @source.split("/", 2)[1][0..-4] + ".html"
      @shortcodes = Shortcodes.parse(@text)
    end

    def html
      @html, @toc = Discount.compile(
        replace_shortcodes,
        @metadata.fetch("toc", nil) != nil)
      @html = HtmlFilters.downgrade_headers(@html)
      @html = HtmlFilters.make_links_absolute(@html, @link)
    end

    def date
      return @date if @date != nil
      t = @metadata.fetch("date", nil)
      if t != nil
        # TODO, un-hardcode UTC
        @date = Time.parse(t.to_s, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
      end
      @date
    end

    # Path for the `Templates::Template` this post should be rendered with
    def template
      @metadata.fetch("template", "templates/post.tmpl").to_s
    end

    # Render the markdown HTML into the right template for the fragment
    def rendered
      context = @metadata.merge(value)
      Templates::Env.get_template(template).render(context)
    end

    def replace_shortcodes
      @shortcodes.errors.each do |e|
        # TODO: show actual error
        Log.error { "In #{@source}:" }
        Log.error { Shortcodes.nice_error(e, @text) }
      end
      text = @text
      # Starting at the end of text, go backwards
      # replacing each shortcode with its output
      @shortcodes.shortcodes.reverse_each do |sc|
        # FIXME: context needs stuff
        context = Crinja::Context.new
        text = text[0, sc.position] +
               Sc.render_sc(sc, context) +
               text[sc.position + sc.len, text.size]
      end
      text
    end

    def summary
      return @metadata["summary"] if @metadata.has_key?("summary")
      # Split HTML in the comment
      if @html.includes?("<!--more-->")
        @html.split("<!--more-->")[0]
      else
        @html
      end
    end

    # What to show as breadcrumbs for this post
    def breadcrumbs
      # This is hard to guess, but ...
      # For pages, it can follow the path.
      # For things inside posts/ it can just be empty
      return [{name: "Posts", link: "/posts"}, {name: @title}] if date
      [] of String
    end

    # Return a value Crinja can use in templates
    # FIXME: can Crinja handle the object directly
    # if it uses properties?
    def value
      {
        "title"       => @title,
        "link"        => @link,
        "date"        => date,
        "html"        => html,
        "source"      => @source,
        "summary"     => summary,
        "toc"         => @toc,
        "breadcrumbs" => breadcrumbs,
      }
    end

    # List of all files and kv store items this post uses
    def dependencies : Array(String)
      result = ["conf", "kv://templates/page.tmpl"]
      result << self.@source
      result << "kv://#{template}"
      result += self.@shortcodes.shortcodes.map { |sc| "kv://shortcodes/#{sc.name}.tmpl" }
      result
    end
  end

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

      output = "output#{post.@link}"
      Croupier::Task.new(
        id: "markdown",
        output: output,
        inputs: post.dependencies,
        mergeable: false,
        proc: Croupier::TaskProc.new {
          post.load # Need to refresh post contents
          Log.info { ">> #{output}" }
          Render.apply_template("templates/page.tmpl",
            {"content" => post.rendered})
        }
      )
    end
  end

  # Create an index page out of a list of posts, save in output
  def self.render_index(posts, output, title = nil, extra_inputs = [] of String)
    inputs = [
      "conf",
      "kv://templates/index.tmpl",
      "kv://templates/page.tmpl",
    ] + posts.map(&.@source) + posts.map(&.template) + extra_inputs
    inputs = inputs.uniq
    Croupier::Task.new(
      id: "index",
      output: output,
      inputs: inputs,
      mergeable: false,
      proc: Croupier::TaskProc.new {
        Log.info { ">> #{output}" }
        content = Templates::Env.get_template("templates/index.tmpl").render(
          {
            "posts" => posts.map(&.value),
          })
        Render.apply_template("templates/page.tmpl",
          {"content" => content, "title" => title})
      }
    )
  end

  # Create a RSS file out of posts with title, save in output
  def self.render_rss(posts, title, output)
    inputs = ["conf"] + posts.map { |post| post.@source }

    Croupier::Task.new(
      id: "rss",
      output: output,
      inputs: inputs,
      mergeable: false,
      proc: Croupier::TaskProc.new {
        Log.info { ">> #{output}" }
        feed = RSS.new title: title
        posts.each do |post|
          feed.item(
            title: post.@title,
            description: post.summary,
            link: post.@link,
            pubDate: post.date.to_s,
          )
        end
        feed.xml indent: true
      }
    )
  end

  # Parse all markdown posts in a path and build Markdown::File
  # objects out of them
  def self.read_all(path)
    Log.info { "Reading Markdown from #{path}" }
    posts = [] of File
    Dir.glob("#{path}/**/*.md").each do |p|
      posts << File.new(p)
    end
    posts
  end
end
