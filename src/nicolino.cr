# Nicolino, a basic static site generator.

require "yaml"
require "./post"
require "./template"
require "./util"

VERSION = "0.1.0"

# Load config file
Util.log("Loading configuration")
config = File.open("conf") do |file|
  YAML.parse(file).as_h
end

Templates.init("templates")

page_template = Templates::Template.templates["templates/page.tmpl"].@compiled
posts = Post::Markdown.read_all
Util.log("Rendering output")
posts.each do |post|
  output = "output/#{post.@link}"
  Util.log("    #{output}")
  rendered_page = Crustache.render(page_template,
    config.merge({
      "content" => post.rendered,
    }))
  File.open(output, "w") do |io|
    io.puts rendered_page
  end
end
