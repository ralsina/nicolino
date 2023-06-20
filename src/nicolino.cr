# Nicolino, a basic static site generator.

require "./assets"
require "./config"
require "./markdown"
require "./render"
require "./template"
require "./util"
require "croupier"
require "yaml"

VERSION = "0.1.0"

def run(options, arguments)
  # Load config file
  Config.config

  page_template = Templates::Template.get("templates/page.tmpl")

  # Copy assets/ to output/
  Assets.render()

  # Render posts and RSS feed
  posts = Markdown::File.read_all("posts")
  Render.render(posts, page_template, require_date: true)

  Render.render_rss(
    posts[..10],
    Config.config["title"].to_s,
    "output/rss.xml"
  )

  # Render pages
  pages = Markdown::File.read_all("pages")
  Render.render(pages, page_template, require_date: false)

  # Run tasks for real
  Util.log("Writing output files:")
  if options.bool["parallel"]
    Croupier::TaskManager.run_tasks_parallel
  else
    Croupier::TaskManager.run_tasks
  end
  Util.log("Done!")
end
