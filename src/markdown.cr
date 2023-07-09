require "./html_filters"
require "cr-discount"

module Markdown
  alias ValueType = Hash(String, String | Time | Nil | Array(String))

  # A class representing a Markdown file
  class File
    @metadata = Hash(String, String).new
    @text : String = ""
    @link : String = ""
    @html : String = ""
    @title : String = ""
    @source : String = ""
    @rendered : String = ""
    @date : Time | Nil

    # Initialize the post with proper data
    def initialize(path)
      # TODO: lazy load data
      @source = path
      load
    end

    def load
      Log.info { "<< #{@source}" }
      contents = ::File.read(@source)
      _, metadata, @text = contents.split("---\n", 3)
      @metadata = YAML.parse(metadata).as_h.map { |k, v| [k.as_s.downcase.strip, v.to_s] }.to_h
      @title = @metadata["title"].to_s
      @link = "/" + @source.split("/", 2)[1][0..-4] + ".html"
    end

    def html
      flags = Discount::MKD_FENCEDCODE | Discount::MKD_TOC
      doc = Discount.mkd_string(@text.to_unsafe, @text.bytesize, flags)
      Discount.mkd_compile(doc, flags)
      html = Pointer(Pointer(LibC::Char)).malloc 1
      size = Discount.mkd_document(doc, html)
      slice = Slice.new(html.value, size)
      @html = String.new(slice)
      if @metadata.fetch("toc", nil)
        toc = Pointer(Pointer(LibC::Char)).malloc 1
        toc_size = Discount.mkd_toc(doc, toc)
        toc_s = String.new(Slice.new(toc.value, toc_size))
        @html = toc_s + @html
      end
      Discount.mkd_cleanup(doc)
      HtmlFilters.downgrade_headers(@html)
    end

    def date
      t = @metadata.fetch("date", nil)
      if t != nil
        # TODO, un-hardcode UTC
        return Time.parse(t.to_s, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
      end
      nil
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

    # Return a value Crinja can use in templates
    # FIXME: can Crinja handle the object directly
    # if it uses properties?
    def value : ValueType
      v = ValueType.new
      v.merge({
        "title"  => @title,
        "link"   => @link,
        "date"   => date,
        "html"   => html,
        "source" => @source,
      })
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
        output: output,
        inputs: ["conf", post.@source, "kv://#{post.template}", "kv://templates/page.tmpl"],
        proc: Croupier::TaskProc.new {
          post.load # Need to refresh post contents
          Log.info { ">> #{output}" }
          Render.apply_template(post.rendered, "templates/page.tmpl")
        }
      )
    end
  end

  # Create an index page out of a list of posts, save in output
  def self.render_index(posts, output)
    inputs = [
      "conf",
      "kv://templates/index.tmpl",
      "kv://templates/page.tmpl",
    ] + posts.map(&.@source) + posts.map(&.template)
    inputs = inputs.uniq
    Croupier::Task.new(
      output: output,
      inputs: inputs,
      proc: Croupier::TaskProc.new {
        Log.info { ">> #{output}" }
        content = Templates::Env.get_template("templates/index.tmpl").render({"posts" => posts.map(&.value)})
        Render.apply_template(content, "templates/page.tmpl")
      }
    )
  end

  # Create a RSS file out of posts with title, save in output
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
