require "./command.cr"
require "../creatable"
require "../markdown"
require "../gallery"
require "crinja"

module Nicolino
  module Commands
    # nicolino new command
    struct New < Command
      @@name = "new"
      @@doc = <<-DOC
Creates a new content item.

The content type is determined by the directory name in the PATH.
Features can register their own creatable types.

Common types:

* content/posts/foo - Blog post
* content/galleries/foo - Image gallery
* content/pages/foo - Static page

Anything else creates a static page.

Usage:
  nicolino new [--help] PATH [-c <file>][-q|-v <level>]

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything [default: false]
DOC

      def run : Int32
        # Populate the creatable registry with built-in types
        register_builtins

        path = Path[@options["PATH"].as(String)]
        raise "Can't create #{path}, new is used to create data inside #{Config.options.content}" \
          if path.parts[0] != Config.options.content.rstrip("/")

        # Determine content type from directory
        if path.parts.size < 3
          kind = "page"
        else
          dir_name = path.parts[1]
          kind = if ct = Creatable.find_by_directory(dir_name)
                   ct.name
                 else
                   "page"
                 end
        end

        # Find and call the creator
        if ct = Creatable.all.find { |ct_item| ct_item.name == kind }
          Log.info { "Creating new #{kind}: #{path}" }
          ct.creator.call(path)
          0
        else
          Log.error { "Unknown content type: #{kind}" }
          1
        end
      rescue ex : Exception
        Log.error(exception: ex) { "Error creating new content: #{ex.message}" }
        1
      end

      # Register built-in content types
      private def register_builtins
        # Only register if not already populated
        return unless Creatable.all.empty?

        Creatable.register("post", "posts", "Blog post") do |path|
          Markdown.new_post(path)
        end

        Creatable.register("gallery", "galleries", "Image gallery") do |path|
          raise "Galleries are folders, not documents" if path.to_s.ends_with?(".md")
          gallery_path = path / "index.md"
          Log.info { "Creating new gallery #{gallery_path}" }
          raise "#{gallery_path} already exists" if ::File.exists?(gallery_path)
          Dir.mkdir_p(gallery_path.dirname)
          ::File.open(gallery_path, "w") do |io|
            template = <<-TEMPLATE
---
title: Add title here
date: {{date}}
---

Add content here
TEMPLATE
            io << Crinja.render(template, {date: Time.local.to_s})
          end
        end

        Creatable.register("page", "pages", "Static page") do |path|
          Markdown.new_page(path)
        end
      end
    end
  end
end

Nicolino::Commands::New.register
