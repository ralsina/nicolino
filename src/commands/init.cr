require "./command.cr"
require "baked_file_system"

module Nicolino
  module Commands
    # nicolino init command
    struct Init < Command
      @@name = "init"
      @@doc = <<-DOC
Create a new site

When given a path, it will create a folder with the
skeleton of a Nicolino site in it, ready to use.

Usage:
  nicolino init [--help] PATH [-c <file>][-q|-v <level>]

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything
DOC

      def run : Int32
        path = options["PATH"].as(String)
        raise Exception.new("#{path} already exists") if File.exists? path

        FileUtils.mkdir_p(path)
        Dir.cd path do
          [TemplateFiles, ShortcodesFiles, AssetsFiles, RootFiles].each do |klass|
            klass.expand
          end
          FileUtils.mkdir_p("content/posts")
          FileUtils.mkdir_p("content/galleries")
          Log.info { "✔️ Done, start writing things in content!" }
        end
        0
      rescue ex : Exception
        Log.error(exception: ex) { "Error creating site: #{ex.message}" }
        Log.debug { ex.backtrace.join("\n") }
        1
      end

      # This command needs a custom initialize because we don't have
      # a config file yet.
      def initialize(@options)
        # Setup logging
        verbosity = @options.fetch("-v", 4).to_s.to_i
        verbosity = 0 if @options["-q"] == 1
        progress = @options.fetch("--progress", nil)
        if progress
          verbosity = 0
          theme = Progress::Theme.new(
            complete: "-",
            incomplete: "•".colorize(:blue).to_s,
            progress_head: "C".colorize(:yellow).to_s,
            alt_progress_head: "c".colorize(:yellow).to_s,
          )
          bar = Progress::Bar.new(theme: theme)
          done = 0
          Croupier::TaskManager.progress_callback = ->(_id : String) {
            done += 1
            step = done * 100.0 / Croupier::TaskManager.tasks.size - bar.current
            bar.tick(step) if step >= 1
          }
        end
        Oplog.setup(verbosity)
      end
    end
  end

  # A self-expanding BakedFileSystem
  class Expandable
    extend BakedFileSystem
    class_property path : String = ""

    def self.expand
      @@files.each do |file|
        path = Path[self.path, file.path[1..]].normalize
        FileUtils.mkdir_p(File.dirname(path))
        Log.info { "👉 Creating #{path}" }
        File.open(path, "w") { |outf|
          outf << file.gets_to_end
        }
      end
    end
  end

  # Files that go in templates/
  class TemplateFiles < Expandable
    @@path = "templates"
    bake_folder "../../themes/default/templates"
  end

  # Files that go in shortcodes/
  class ShortcodesFiles < Expandable
    @@path = "shortcodes"
    bake_folder "../../shortcodes"
  end

  # Files that go in assets/
  class AssetsFiles < Expandable
    @@path = "assets"
    bake_folder "../../themes/default/assets"
  end

  # Files that go in the root of the site
  class RootFiles < Expandable
    @@path = "."
    bake_folder "defaults", "."
  end
end

Nicolino::Commands::Init.register
