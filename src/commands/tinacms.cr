require "./command.cr"
require "baked_file_system"

module Nicolino
  module Commands
    # nicolino tinacms command
    struct Tinacms < Command
      @@name = "tinacms"
      @@doc = <<-DOC
Initialize TinaCMS for content management

Usage:
  nicolino tinacms init [-c <file>][-q|-v <level>]
  nicolino tinacms serve [-c <file>][-q|-v <level>]
  nicolino tinacms [--help]

Commands:
  init   Initialize TinaCMS in an existing Nicolino site
  serve  Start TinaCMS dev server with nicolino auto

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything

TinaCMS provides a visual content management interface for Nicolino sites.

For more information, see: https://tina.io/docs/
DOC

      def run : Int32
        # Determine which subcommand was called based on which options are present
        return run_serve if @options["serve"]?
        run_init
      rescue ex : Exception
        Log.error(exception: ex) { "Error: #{ex.message}" }
        Log.debug { ex.backtrace.join("\n") }
        1
      end

      # This command needs a custom initialize because we're setting up
      # a new subsystem and want to control logging explicitly
      def initialize(@options)
        # Setup logging only
        verbosity = @options.fetch("-v", 4).to_s.to_i
        verbosity = 0 if @options["-q"]? == 1
        Oplog.setup(verbosity)
      end

      private def run_init : Int32
        # Check if we're in a valid nicolino site
        unless File.exists?("conf.yml")
          Log.error { "No conf.yml found. Are you in a Nicolino site?" }
          Log.info { "Run 'nicolino init .' first to create a new site" }
          return 1
        end

        # Check if TinaCMS is already initialized
        if File.exists?("tina/config.ts")
          Log.warn { "TinaCMS appears to be already initialized (tina/config.ts exists)" }
          Log.info { "Delete the tina/ directory and run again to re-initialize" }
          return 1
        end

        # Create directory structure
        Log.info { "Creating TinaCMS directory structure..." }
        FileUtils.mkdir_p("tina")
        FileUtils.mkdir_p("content/media")

        # Expand default files
        TinaConfigFiles.expand

        # Create tina/.gitignore manually (BakedFileSystem may not handle dotfiles)
        Log.info { "👉 Creating tina/.gitignore" }
        File.write("tina/.gitignore", "__generated__/\n")

        # Always create package.json
        create_package_json

        # Run npm install
        Log.info { "Installing npm dependencies (this may take a while)..." }
        install_status = Process.run("npm", ["install"],
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit)

        unless install_status.success?
          Log.error { "npm install failed" }
          Log.info { "You can run it manually later: npm install" }
          return 1
        end

        # Note: The 'dev' command will build as needed, so we don't need
        # to run 'build' separately here

        # Success!
        Log.info { "" }
        Log.info { "TinaCMS initialized successfully!" }
        Log.info { "" }
        Log.info { "Next steps:" }
        Log.info { "  1. Start the development server:" }
        Log.info { "     nicolino tinacms serve" }
        Log.info { "" }
        Log.info { "  Note: The dev server will build TinaCMS automatically" }
        Log.info { "        on first run. For production deployment, set up" }
        Log.info { "        Tina Cloud and run: npx @tinacms/cli@latest build" }
        Log.info { "" }
        Log.info { "Configuration files:" }
        Log.info { "  - package.json       - npm dependencies" }
        Log.info { "  - tina/config.ts     - Main TinaCMS configuration" }
        Log.info { "  - tina/tina-lock.json - Schema lock file (commit this)" }
        Log.info { "  - tina/.gitignore     - Ignores auto-generated files" }
        Log.info { "" }

        0
      end

      private def run_serve : Int32
        # Check if TinaCMS is initialized
        unless File.exists?("tina/config.ts")
          Log.error { "TinaCMS not initialized (tina/config.ts not found)" }
          Log.info { "Run 'nicolino tinacms init' first" }
          return 1
        end

        # Check if node_modules exists
        unless File.exists?("node_modules")
          Log.error { "node_modules not found" }
          Log.info { "Run 'npm install' first" }
          return 1
        end

        Log.info { "Starting TinaCMS dev server with nicolino auto..." }
        Log.info { "" }
        Log.info { "TinaCMS admin will be available at:" }
        Log.info { "  http://localhost:8080/admin/" }
        Log.info { "" }
        Log.info { "Press Ctrl+C to stop both servers" }
        Log.info { "" }

        # Start both processes
        tinacms_process = Process.new("npx", ["@tinacms/cli@latest", "dev"],
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit)

        # Use the current executable to run nicolino auto
        nicolino_path = Process.executable_path || "nicolino"
        nicolino_process = Process.new(nicolino_path, ["auto"],
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit)

        # Wait for either process to exit
        begin
          tinacms_process.wait
        rescue ex : Exception
          # Process was terminated
        ensure
          # Clean up both processes
          tinacms_process.terminate if tinacms_process.exists?
          nicolino_process.terminate if nicolino_process.exists?
        end

        0
      end

      private def create_package_json : Int32
        Log.info { "Creating package.json..." }

        package_json = {
          "dependencies" => {
            "tinacms" => "^3.3.2",
          },
          "devDependencies" => {
            "@tinacms/cli" => "^2.1.2",
            "@types/node"  => "^25.1.0",
          },
        }.to_json

        File.write("package.json", package_json)

        # Add node_modules to .gitignore
        gitignore_path = ".gitignore"
        if File.exists?(gitignore_path)
          gitignore_content = File.read(gitignore_path)
          unless gitignore_content.includes?("node_modules")
            File.open(gitignore_path, "a") do |file|
              file.puts("\n# TinaCMS/npm\nnode_modules/")
            end
          end
        else
          File.write(gitignore_path, "# TinaCMS/npm\nnode_modules/\n")
        end

        0
      end
    end
  end

  # A self-expanding BakedFileSystem for TinaCMS configuration
  class TinaConfigFiles
    extend BakedFileSystem
    @@path = "tina"
    bake_folder "../../tinacms_defaults"

    def self.expand
      @@files.each do |file|
        path = Path[@@path, file.path[1..]].normalize
        FileUtils.mkdir_p(File.dirname(path))
        Log.info { "👉 Creating #{path}" }
        File.open(path, "w") do |outf|
          outf << file.gets_to_end
        end
      end
    end
  end
end

Nicolino::Commands::Tinacms.register
