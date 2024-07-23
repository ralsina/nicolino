require "./command.cr"

module Nicolino
  module Commands
    # Run forever automatically rebuilding the site
    struct Build < Command
      @@name = "build"
      @@doc = <<-DOC
Build the site

Build the output site based on your content and configuration.
If you specify one or more TARGETs, only those files will be
built. If you don't specify any, the whole site will be built.

Usage:
  nicolino build [TARGET...] [--fast-mode][-n][-p][--progress][-k][-q][-B][-c <file>][-q|-v <level>]

Options:
  --help            Help for this command.
  -B --run-all      Run all tasks, even up-to-date ones
  -c <file>         Specify a config file to use [default: conf.yml]
  -k --keep-going  Keep going when a task fails.
  -n --dry-run     Dry run: don't actually do anything
  -p --parallel    Run tasks in parallel.
  --fast-mode       Use file timestamps rather than contents to decide rebuilds.
  --progress        Show a progress bar instead of messages
  -q                Don't log anything [default: false]
  -v level          Control the verbosity, 0 to 6 [default: 4]

DOC

      def run : Int32
        arguments = options.fetch("TARGET", [] of String).as(Array(String))
        run(
          arguments: arguments,
          parallel: !options["--parallel"].nil?,
          keep_going: !options["--keep-going"].nil?,
          dry_run: !options["--dry-run"].nil?,
          run_all: !options["--run-all"].nil?,
          fast_mode: !options["--fast-mode"].nil?,
        )
        0
      rescue ex : Exception
        Log.error(exception: ex) { "Error running build: #{ex.message}" }
        Log.debug { ex.backtrace.join("\n") }
        1
      end
    end
  end
end

Nicolino::Commands::Build.register
