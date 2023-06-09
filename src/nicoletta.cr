# Nicoletta, a minimal static site generator.

require "yaml"
require "markd"
require "crustache"

VERSION = "0.1.0"

# Load config file
tpl_data = File.open("conf") do |file|
  YAML.parse(file).as_h
end

class Template
  @text : String
  @compiled : Crustache::Syntax::Template

  def initialize(path)
    @text = File.read(path)
    @compiled = Crustache.parse(@text)
  end
end

# Load templates
templates = {} of String => Template

Dir.glob("templates/*.tmpl").each do |path|
  templates[path] = Template.new(path)
end

class Post
  @metadata = {} of YAML::Any => YAML::Any
  @text : String
  @link : String
  @html : String

  def initialize(path)
    contents = File.read(path)
    metadata, @text = contents.split("\n\n", 2)
    @metadata = YAML.parse(metadata).as_h
    @link = path.split("/")[-1][0..-4] + ".html"
    @html = Markd.to_html(@text)
  end

  def render(template)
    Crustache.render template.@compiled, @metadata.merge({"link" => @link, "text" => @html})
  end
end

Dir.glob("posts/*.md").each do |path|
  post = Post.new(path)
  rendered_post = post.render templates["templates/post.tmpl"]
  rendered_page = Crustache.render(templates["templates/page.tmpl"].@compiled,
    tpl_data.merge({
      "content" => rendered_post,
    }))
  File.open("output/#{post.@link}", "w") do |io|
    io.puts rendered_page
  end
end
