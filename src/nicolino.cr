# Nicoletta, a minimal static site generator.

require "yaml"
require "markd"
require "./post"
require "./template"
require "./util"

VERSION = "0.1.0"

# Load config file
config = File.open("conf") do |file|
  YAML.parse(file).as_h
end

Templates.init("templates")
Post::Markdown.render_all(config)
