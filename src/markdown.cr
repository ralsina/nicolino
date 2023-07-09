require "./html_filters"
require "cr-discount"

module Markdown
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
      doc = Discount.mkd_string(@text.to_unsafe, @text.bytesize, Discount::FLAGS)
      Discount.mkd_compile(doc, Discount::FLAGS)
      html = Pointer(Pointer(LibC::Char)).malloc 1
      size = Discount.mkd_document(doc, html)
      slice = Slice.new(html.value, size)
      @html = String.new(slice)
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
      Templates::Env.get_template(template).render(
        @metadata.merge({"link" => @link, "text" => html}))
    end

    # Return a value Crinja can use in templates
    # FIXME: can Crinja handle the object directly
    # if it uses properties?
    def value
      {
        "title"    => @title,
        "link"     => @link,
        "date"     => date,
        "html"     => html,
        "source"   => @source,
        "rendered" => rendered,
      }
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
end
