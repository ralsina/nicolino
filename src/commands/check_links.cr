require "./command.cr"
require "../link_checker"

module Nicolino
  module Commands
    # nicolino check_links command
    #
    # Validates that all in-site links point to existing files.
    # This helps catch broken links when porting or updating content.
    struct CheckLinks < Command
      @@name = "check_links"
      @@doc = <<-DOC
Check all in-site links for broken references.

Scans all HTML files in the output directory and verifies that
internal links point to existing files. This is useful when
porting a site to ensure no links were broken in the process.

External links (http://, https://, mailto:, etc.) are skipped.
Anchors (same-page links starting with #) are also skipped.

Usage:
  nicolino check_links [--help][-c <file>][-q|-v <level>][--output <dir>]

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  --output <dir>    Output directory to check [default: output]
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything
DOC

      def run : Int32
        output_dir = @options["--output"]? ? @options["--output"].as(String) : Config.options.output

        # Check if output directory exists
        unless Dir.exists?(output_dir)
          Log.error { "Output directory '#{output_dir}' does not exist. Run 'nicolino build' first." }
          return 1
        end

        results = LinkChecker.check_all(output_dir)
        broken_count = LinkChecker.print_summary(results)

        if broken_count > 0
          Log.error { "Found #{broken_count} broken link(s)" }
          return 1
        end

        Log.info { "All links checked successfully!" }
        0
      end
    end
  end
end

Nicolino::Commands::CheckLinks.register
