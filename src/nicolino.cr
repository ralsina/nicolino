# Nicolino, a basic static site generator.

require "yaml"
require "./markdown"
require "./template"
require "./util"
require "./render"

VERSION = "0.1.0"

# Load config file
Util.log("Loading configuration")
config = File.open("conf") do |file|
  YAML.parse(file).as_h
end

Templates.init("templates")
page_template = Templates::Template.templates["templates/page.tmpl"].@compiled

posts = Markdown::File.read_all("posts")
Util.log("Rendering output for posts")
posts.each do |post|
  output = "output/#{post.@link}"
  Util.log("    #{output}")
  if post.date == nil
    Util.log("Error: #{post.@source} has no date")
    next
  end
  Render.write(post.rendered, page_template, output, config)
end

pages = Markdown::File.read_all("pages")
Util.log("Rendering output for pages")
pages.each do |post|
  output = "output/#{post.@link}"
  Util.log("    #{output}")
  Render.write(post.rendered, page_template, output, config)
end

