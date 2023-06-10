module Post
  class Markdown
    @metadata = {} of YAML::Any => YAML::Any
    @text   : String
    @link   : String
    @html   : String
    @source : String

    def initialize(path)
      contents = File.read(path)
      _, metadata, @text = contents.split("---\n", 3)
      @metadata = YAML.parse(metadata).as_h
      @link = path.split("/")[-1][0..-4] + ".html"
      @html = Markd.to_html(@text)
      @source = path
    end

    def template
        @metadata.fetch("template", "templates/post.tmpl")
    end

    def dependencies
        [@source, template()]
    end

    def render
      # Render the markdown HTML into the right template for the fragment
      # TODO: un-hardcode post.tmpl
      t= Templates::Template.templates[template()]
      Crustache.render t.@compiled, @metadata.merge({"link" => @link, "text" => @html})
    end

    def self.render_all(config)
      # Parse all markdown files and render them
      # Uses config as template data
      Util.log("Processing Markdown")
      Dir.glob("posts/*.md").each do |path|
        post = Post::Markdown.new(path)
        Util.log("    #{path}")
        rendered_post = post.render
        rendered_page = Crustache.render(Templates::Template.templates["templates/page.tmpl"].@compiled,
          config.merge({
            "content" => rendered_post,
          }))
        File.open("output/#{post.@link}", "w") do |io|
          io.puts rendered_page
        end
      end
    end
  end
end
