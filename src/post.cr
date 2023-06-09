module Post
  class Markdown
    @metadata = {} of YAML::Any => YAML::Any
    @text : String
    @link : String
    @html : String

    def initialize(path)
      contents = File.read(path)
      _, metadata, @text = contents.split("---\n", 3)
      @metadata = YAML.parse(metadata).as_h
      @link = path.split("/")[-1][0..-4] + ".html"
      @html = Markd.to_html(@text)
    end

    def render
      # Render the markdown HTML into the right template for the fragment
      # TODO: un-hardcode post.tmpl
      template = Templates::Template.templates["templates/post.tmpl"]
      Crustache.render template.@compiled, @metadata.merge({"link" => @link, "text" => @html})
    end
  end
end
