require "./command.cr"
require "../import"

module Nicolino
  module Commands
    # nicolino import command
    #
    # Imports content from external RSS/Atom feeds and generates posts.
    # Similar to Nikola's continuous import feature.
    struct Import < Command
      @@name = "import"
      @@doc = <<-DOC
Import content from external RSS/Atom feeds or JSON APIs.

Fetches data from configured feeds and generates posts based on templates.
This allows you to automatically bring in content from services like
Goodreads, YouTube, blogs, or any JSON API.

Usage:
  nicolino import [--help][-c <file>][-q|-v <level>][--feed <name>]

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  --feed <name>     Import only a specific feed (imports all if not specified)
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything

Configuration:

Add an 'import' section to your conf.yml with feed configurations:

  import:
    goodreads:
      urls:
        - "https://www.goodreads.com/review/list_rss/USER_ID?shelf=read"
      fields:
        title: title
        date: user_read_at
        content: description
      template: "goodreads.tmpl"
      output_folder: "posts/goodreads"
      format: "md"
      tags: "books, goodreads"
      skip_titles:
        - "Book to Skip"

    # JSON API example (Pocketbase, etc.)
    blog:
      urls:
        - "http://localhost:8090/api/collections/articles/records"
      feed_format: "json"
      fields:
        title: title
        date: published
        tags: tags
        content: content
      output_folder: "posts"
      format: "html"
      template: "article.tmpl"

Templates should be placed in templates/import/ directory and
use Crinja (Jinja2-like) syntax. Templates receive variables based
on your 'fields' mapping configuration:
  - {{title}} - Mapped from the configured source field
  - {{date}} - Mapped from the configured source field
  - {{content}} - Mapped from the configured source field
  - {{lang}} - The configured language
  - Any other fields you define in 'fields' or 'static'
DOC

      def run : Int32
        feed_name = @options["--feed"]? ? @options["--feed"].as(String) : nil

        if feed_name
          import_single_feed(feed_name)
        else
          ::Import.import_all
        end

        0
      rescue ex : Exception
        Log.error(exception: ex) { "Error during import: #{ex.message}" }
        Log.debug { ex.backtrace.join("\n") }
        1
      end

      private def import_single_feed(feed_name : String)
        ci_result = Config.options.import

        if ci_result.nil? || ci_result.empty?
          Log.error { "No import configuration found in conf.yml" }
          return 1
        end

        feeds = ci_result

        unless feeds.has_key?(feed_name)
          Log.error { "Feed '#{feed_name}' not found in configuration" }
          Log.error { "Available feeds: #{feeds.keys.join(", ")}" }
          return 1
        end

        feed_yaml = feeds[feed_name]
        feed_cfg = ::Import::FeedConfig.from_any(feed_yaml)

        tmpl_dir = Config.options.import_templates
        ::Import.import_feed(feed_name, feed_cfg, tmpl_dir)
        0
      end
    end
  end
end

Nicolino::Commands::Import.register
