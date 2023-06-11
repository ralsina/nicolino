require "markd"

module Markdown
  # A class representing a Markdown file
  class File
    @metadata = {} of YAML::Any => YAML::Any
    @text : String
    @link : String
    @html : String
    @title : String
    @source : String
    @rendered : String = ""
    @date : Time | Nil

    # Initialize the post with proper data
    def initialize(path)
      contents = ::File.read(path)
      _, metadata, @text = contents.split("---\n", 3)
      # TODO normalize metadata key case
      @metadata = YAML.parse(metadata).as_h
      @title = @metadata["title"].to_s
      @link = path.split("/", 2)[1][0..-4] + ".html"
      @html = Markd.to_html(@text)
      @source = path
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
      t = Templates::Template.templates[template()]
      Crustache.render t.@compiled, @metadata.merge({"link" => @link, "text" => @html})
    end

    # Parse all markdown posts in a path and build Markdown objects out of them
    def self.read_all(path)
      Util.log("Reading Markdown from #{path}")
      posts = [] of File
      Dir.glob("#{path}/**/*.md").each do |p|
        Util.log("    #{p}")
        posts << File.new(p)
      end
      posts
    end
  end
end
