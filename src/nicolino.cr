# Nicolino, a basic static site generator.

require "commander"
require "croupier"
require "yaml"
require "./config"
require "./markdown"
require "./template"
require "./util"
require "./render"

VERSION = "0.1.0"

def run(options, arguments)
  # Load config file
  Config.config

  page_template = Templates::Template.get("templates/page.tmpl")

  posts = Markdown::File.read_all("posts")
  Render.render(posts, page_template, require_date: true)

  Render.render_rss(
    posts[..10],
    Config.config["title"].to_s,
    "output/rss.xml"
  )

  pages = Markdown::File.read_all("pages")
  Render.render(pages, page_template, require_date: false)

  Util.log("Writing output files:")
  if options.bool["parallel"]
    Croupier::Task.run_tasks_parallel
  else
    Croupier::Task.run_tasks
  end
  Util.log("Done!")
end

cli = Commander::Command.new do |cmd|
  cmd.use = "nicolino"
  cmd.long = "nicolino builds websites from markdown files."

  cmd.flags.add do |flag|
    flag.name = "parallel"
    flag.short = "-p"
    flag.long = "--parallel"
    flag.default = false
    flag.description = "Run tasks in parallel."
    flag.persistent = true
  end

  cmd.run do |options, arguments|
    options.bool["parallel"]
    run(options, arguments)
  end
end

Commander.run(cli, ARGV)
