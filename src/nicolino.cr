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
# TODO make config a singleton
Render.render(posts, page_template, config)

pages = Markdown::File.read_all("pages")
Util.log("Rendering output for pages")
Render.render(pages, page_template, config, false)

