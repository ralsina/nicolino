require "./command.cr"

module Nicolino
  module Commands
    struct Validate < Command
      @@name = "validate"
      @@doc = <<-DOC
Check your content for errors.

Currently it will validate markdown and pandoc documents.
More checks will be added over time.

Usage:
  nicolino validate [-c <file>][-q|-v <level>]
Options:
  -c <file>         Specify a config file to use [default: conf.yml]
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything
DOC

      def run : Int32
        features = Set.new(Config.get("features").as_a)
        content_path = Path[Config.options.content]
        content_post_path = content_path / Config.options.posts

        error_count = 0
        if features.includes? "posts"
          posts = Markdown.read_all(content_post_path)
          posts += HTML.read_all(content_post_path)
          posts += Pandoc.read_all(content_post_path) if features.includes? "pandoc"
          if !posts.nil?
            error_count += Markdown.validate(posts, require_date: true)
          end
        end

        if features.includes? "pages"
          pages = Markdown.read_all(content_path)
          pages += HTML.read_all(content_path)
          pages += Pandoc.read_all(content_path) if features.includes? "pandoc"
          if !pages.nil?
            error_count += Markdown.validate(pages, require_date: false)
          end
        end
        if error_count > 0
          Log.error { "Validation failed with #{error_count} errors" }
          return 1
        end
        Log.info { "Looks ok." }
        0
      end
    end
  end
end

Nicolino::Commands::Validate.register
