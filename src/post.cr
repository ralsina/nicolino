require "markd"

module Post
  # A class representing a Markdown file
  class Markdown
    @metadata = {} of YAML::Any => YAML::Any
    @text : String
    @link : String
    @html : String
    @source : String
    @rendered : String = ""

    # Initialize the post with proper data
    def initialize(path)
      contents = File.read(path)
      _, metadata, @text = contents.split("---\n", 3)
      @metadata = YAML.parse(metadata).as_h
      @link = path.split("/")[-1][0..-4] + ".html"
      @html = Markd.to_html(@text)
      @source = path
      @rendered = rendered
    end

    # Path for the `Templates::Template` this post should be rendered with
    def template
      @metadata.fetch("template", "templates/post.tmpl")
    end

    # Paths for dependencies, things that would mark this post as stale
    def dependencies
      [@source, template()]
    end

    # Render the markdown HTML into the right template for the fragment
    # TODO: un-hardcode post.tmpl
    def rendered
      t = Templates::Template.templates[template()]
      Crustache.render t.@compiled, @metadata.merge({"link" => @link, "text" => @html})
    end

    # Parse all markdown posts and build Markdown objects out of them
    def self.read_all
      # Parse all markdown files and render them
      # Uses config as template data
      Util.log("Processing Markdown")
      posts = [] of Markdown
      Dir.glob("posts/*.md").each do |path|
        Util.log("    #{path}")
        posts << Post::Markdown.new(path)
      end
      return posts

      rendered_post = post.render
    end
  end
end
