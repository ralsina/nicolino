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
  nicolino init PATH [-c <file>][-q|-v <level>]

Options:
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
    bake_folder "templates", "."
  end

  # Files that go in shortcodes/
  class ShortcodesFiles < Expandable
    @@path = "shortcodes"
    bake_folder "shortcodes", "."
  end

  # Files that go in assets/
  class AssetsFiles < Expandable
    @@path = "assets"
    bake_folder "assets", "."
  end

  # Files that go in the root of the site
  class RootFiles < Expandable
    @@path = "."
    bake_folder "defaults", "."
  end
end

Nicolino::Commands::Init.register
