# Nicolino, a basic static site generator.

require "yaml"
require "croupier"
require "./config"
require "./markdown"
require "./template"
require "./util"
require "./render"

VERSION = "0.1.0"

# Load config file
Config.config

Templates.init("templates")
page_template = Templates::Template.templates["templates/page.tmpl"].@compiled

posts = Markdown::File.read_all("posts")
Render.render(posts, page_template)

Render.render_rss(
  posts[..10],
  Config.config["title"].to_s,
  "output/rss.xml"
)

pages = Markdown::File.read_all("pages")
Render.render(pages, page_template, false)

Util.log("Writing output files:")
Croupier::Task.run_tasks
Util.log("Done!")
