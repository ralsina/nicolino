require "./command.cr"
require "../continuous_import"

module Nicolino
  module Commands
    # nicolino import command
    #
    # Imports content from external RSS/Atom feeds and generates posts.
    # Similar to Nikola's continuous import feature.
    struct Import < Command
      @@name = "import"
      @@doc = <<-DOC
Import content from external RSS/Atom feeds.

Fetches data from configured feeds and generates posts based on templates.
This allows you to automatically bring in content from services like
Goodreads, YouTube, blogs, etc.

Usage:
  nicolino import [--help][-c <file>][-q|-v <level>][--feed <name>]

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  --feed <name>     Import only a specific feed (imports all if not specified)
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything

Configuration:

Add a 'continuous_import' section to your conf.yml with feed configurations:

  continuous_import:
    goodreads:
      urls:
        - "https://www.goodreads.com/review/list_rss/USER_ID?shelf=read"
      template: "goodreads.tmpl"
      output_folder: "posts/goodreads"
      format: "md"
      tags: "books, goodreads"
      skip_titles:
        - "Book to Skip"
      metadata:
        title: "title"
        date: ["user_read_at", "user_date_added", "published"]

    youtube:
      url: "https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID"
      template: "youtube.tmpl"
      output_folder: "posts/youtube"
      format: "md"
      tags: "video, youtube"

Templates should be placed in templates/continuous_import/ directory and
use Crinja (Jinja2-like) syntax. Available variables:
  - {{ item.title }} - The item title
  - {{ item.link }} - The item link
  - {{ item.description }} - The item description
  - {{ item.<field> }} - Any other field from the feed item
DOC

      def run : Int32
        feed_name = @options["--feed"]? ? @options["--feed"].as(String) : nil

        if feed_name
          import_single_feed(feed_name)
        else
          ContinuousImport.import_all
        end

        0
      rescue ex : Exception
        Log.error(exception: ex) { "Error during import: #{ex.message}" }
        Log.debug { ex.backtrace.join("\n") }
        1
      end

      private def import_single_feed(feed_name : String)
        ci_result = Config.options.continuous_import

        if ci_result.nil? || ci_result.empty?
          Log.error { "No continuous_import configuration found in conf.yml" }
          return 1
        end

        feeds = ci_result

        unless feeds.has_key?(feed_name)
          Log.error { "Feed '#{feed_name}' not found in configuration" }
          Log.error { "Available feeds: #{feeds.keys.join(", ")}" }
          return 1
        end

        feed_yaml = feeds[feed_name]
        feed_cfg = ContinuousImport::FeedConfig.from_any(feed_yaml)

        tmpl_dir = Config.options.continuous_import_templates
        ContinuousImport.import_feed(feed_name, feed_cfg, tmpl_dir)
        0
      end
    end
  end
end

Nicolino::Commands::Import.register
