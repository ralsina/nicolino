# Nicoletta, a minimal static site generator.

require "yaml"
require "markd"
require "./post"
require "./template"
require "./util"

VERSION = "0.1.0"

# Load config file
tpl_data = File.open("conf") do |file|
  YAML.parse(file).as_h
end

Templates.init("templates")


Dir.glob("posts/*.md").each do |path|
  post = Post::Markdown.new(path)
  Util.log("Processing #{path}")
  rendered_post = post.render
  rendered_page = Crustache.render(Templates::Template.templates["templates/page.tmpl"].@compiled,
    tpl_data.merge({
      "content" => rendered_post,
    }))
  File.open("output/#{post.@link}", "w") do |io|
    io.puts rendered_page
  end
end
