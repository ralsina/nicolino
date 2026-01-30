require "digest"
require "http"
require "json"

module Nicolino
  module Commands
    # nicolino theme command
    struct Theme < Command
      @@name = "theme"
      @@doc = <<-DOC
Manage Nicolino themes

Usage:
  nicolino theme install <name-or-url> [-c <file>][-q|-v <level>]
  nicolino theme update <name> [-c <file>][-q|-v <level>]
  nicolino theme list [--installed] [-c <file>][-q|-v <level>]
  nicolino theme [--help]

Commands:
  install <name-or-url>  Install a theme from registry or URL
  update <name>           Update an installed theme to latest version
  list [--installed]      List available or installed themes

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything

Themes are installed to the themes/ directory in your site.
The default theme is included with Nicolino and extracted automatically.

Install a theme from the registry:
  nicolino theme install minimal

Install a theme from a URL:
  nicolino theme install https://example.com/theme.tar.gz

List available themes:
  nicolino theme list

List installed themes:
  nicolino theme list --installed
DOC

      THEME_REGISTRY_URL = "https://nicolino.site/themes.json"

      def run : Int32
        # Determine which subcommand was called based on which options are present
        return run_install if @options["<name-or-url>"]?
        return run_update if @options["<name>"]?
        # Must be list command (with or without --installed flag)
        run_list
      rescue ex : Exception
        Log.error(exception: ex) { "Error: #{ex.message}" }
        Log.debug { ex.backtrace.join("\n") }
        1
      end

      # This command needs a custom initialize because we don't necessarily
      # have a config file yet
      def initialize(@options)
        # Setup logging only (no config file needed for theme commands)
        verbosity = @options.fetch("-v", 4).to_s.to_i
        verbosity = 0 if @options["-q"]? == true
        Oplog.setup(verbosity)
      end

      private def run_install : Int32
        name_or_url = @options["<name-or-url>"]?.try(&.as(String))

        unless name_or_url
          Log.error { "Missing theme name or URL" }
          return 1
        end

        # Check if it's a URL
        if name_or_url.starts_with?("http://") || name_or_url.starts_with?("https://")
          install_from_url(name_or_url)
        elsif File.exists?(name_or_url)
          # It's a local file path
          install_from_local_file(name_or_url)
        else
          # It's a theme name, fetch from registry
          install_from_registry(name_or_url)
        end
      end

      private def install_from_url(url : String) : Int32
        # Only allow HTTPS
        unless url.starts_with?("https://")
          Log.error { "Only HTTPS URLs are allowed for theme installation" }
          return 1
        end

        Log.info { "Downloading theme from #{url}..." }
        tarball_data = download_url(url)

        # Extract the theme
        theme_name = extract_theme_from_tarball(tarball_data)
        if theme_name
          Log.info { "Theme '#{theme_name}' installed successfully to themes/#{theme_name}/" }
          0
        else
          Log.error { "Failed to extract theme" }
          1
        end
      end

      private def install_from_local_file(path : String) : Int32
        Log.info { "Installing theme from local file: #{path}" }
        tarball_data = File.read(path).to_slice

        # Extract the theme
        theme_name = extract_theme_from_tarball(tarball_data)
        if theme_name
          Log.info { "Theme '#{theme_name}' installed successfully to themes/#{theme_name}/" }
          0
        else
          Log.error { "Failed to extract theme" }
          1
        end
      end

      private def install_from_registry(name : String) : Int32
        Log.info { "Fetching theme registry..." }
        themes = fetch_themes_json

        unless themes["themes"].as_h.has_key?(name)
          Log.error { "Theme '#{name}' not found in registry" }
          Log.info { "Run 'nicolino theme list' to see available themes" }
          return 1
        end

        theme_info = themes["themes"].as_h[name].as_h
        url = theme_info["url"].as_s
        expected_sha256 = theme_info["sha256"].as_s

        Log.info { "Downloading theme '#{name}' from #{url}..." }
        tarball_data = download_url(url)

        # Verify SHA256
        actual_sha256 = Digest::SHA256.hexdigest(tarball_data)
        if actual_sha256 != expected_sha256
          Log.error { "SHA256 checksum mismatch!" }
          Log.error { "Expected: #{expected_sha256}" }
          Log.error { "Got: #{actual_sha256}" }
          return 1
        end

        # Extract the theme
        extracted_name = extract_theme_from_tarball(tarball_data)
        if extracted_name
          Log.info { "Theme '#{extracted_name}' installed successfully to themes/#{extracted_name}/" }
          0
        else
          Log.error { "Failed to extract theme" }
          1
        end
      end

      private def run_update : Int32
        name = @options["<name>"]?.try(&.as(String))

        unless name
          Log.error { "Missing theme name" }
          return 1
        end

        # Check if theme is installed
        theme_path = Path["themes", name]
        unless Dir.exists?(theme_path)
          Log.error { "Theme '#{name}' is not installed" }
          Log.info { "Install it with: nicolino theme install #{name}" }
          return 1
        end

        Log.info { "Fetching theme registry..." }
        themes = fetch_themes_json

        unless themes["themes"].as_h.has_key?(name)
          Log.error { "Theme '#{name}' not found in registry" }
          return 1
        end

        theme_info = themes["themes"].as_h[name].as_h
        url = theme_info["url"].as_s
        expected_sha256 = theme_info["sha256"].as_s

        Log.info { "Updating theme '#{name}'..." }
        Log.info { "Downloading from #{url}..." }
        tarball_data = download_url(url)

        # Verify SHA256
        actual_sha256 = Digest::SHA256.hexdigest(tarball_data)
        if actual_sha256 != expected_sha256
          Log.error { "SHA256 checksum mismatch!" }
          return 1
        end

        # Remove old theme directory
        Log.info { "Removing old theme directory..." }
        FileUtils.rm_r(theme_path)

        # Extract the theme
        extracted_name = extract_theme_from_tarball(tarball_data)
        if extracted_name
          Log.info { "Theme '#{extracted_name}' updated successfully" }
          0
        else
          Log.error { "Failed to extract theme" }
          1
        end
      end

      private def run_list : Int32
        if @options["--installed"]?
          list_installed
        else
          list_available
        end
      end

      private def list_installed : Int32
        themes_dir = Path["themes"]
        unless Dir.exists?(themes_dir)
          Log.info { "No themes installed" }
          return 0
        end

        themes = Dir.children(themes_dir).select { |entry|
          Dir.exists?(Path[themes_dir, entry])
        }

        if themes.empty?
          Log.info { "No themes installed" }
          return 0
        end

        Log.info { "Installed themes:" }
        themes.each do |theme|
          theme_yml = Path[themes_dir, theme, "theme.yml"]
          if File.exists?(theme_yml)
            # Try to read and parse theme.yml for description
            begin
              content = File.read(theme_yml)
              desc_line = content.lines.find(&.starts_with?("description:"))
              desc = desc_line ? desc_line.split(":", 2)[1].strip : ""
              Log.info { "  #{theme} - #{desc}" }
            rescue
              Log.info { "  #{theme}" }
            end
          else
            Log.info { "  #{theme}" }
          end
        end
        0
      end

      private def list_available : Int32
        Log.info { "Fetching theme registry..." }
        themes = fetch_themes_json

        themes_list = themes["themes"].as_h
        if themes_list.empty?
          Log.info { "No themes available in registry" }
          return 0
        end

        Log.info { "Available themes:" }
        themes_list.each do |name, info|
          info_h = info.as_h
          description = info_h["description"]?.try(&.as_s) || ""
          Log.info { "  #{name} - #{description}" }
        end
        Log.info { "" }
        Log.info { "Install with: nicolino theme install <name>" }
        0
      end

      private def fetch_themes_json : JSON::Any
        response = HTTP::Client.get(THEME_REGISTRY_URL)
        unless response.success?
          raise "Failed to fetch themes.json: #{response.status_code}"
        end
        JSON.parse(response.body)
      end

      private def download_url(url : String) : Slice(UInt8)
        response = HTTP::Client.get(url)
        unless response.success?
          raise "Failed to download #{url}: #{response.status_code}"
        end
        response.body.to_slice
      end

      private def extract_theme_from_tarball(tarball_data : Slice(UInt8)) : String?
        # Create a temporary file for the tarball
        temp_tarball = File.tempfile("theme", ".tar.gz")
        temp_tarball.write(tarball_data)
        temp_tarball.close

        # Extract using tar command
        # First, let's figure out the theme name by listing contents
        list_output = IO::Memory.new
        list_status = Process.run("tar", ["-tzf", temp_tarball.path], output: list_output)
        unless list_status.success?
          raise "Failed to list tarball contents"
        end

        # Get the first entry to determine theme name
        # Skip directory entries and find the first file
        list_output.rewind
        content = list_output.gets_to_end
        lines = content.lines
        first_file_entry = lines.find { |line|
          parts = line.split('/', remove_empty: true)
          # We want a file (not just a directory) under themes/<name>/
          parts.size >= 3 && parts[0] == "themes"
        }

        unless first_file_entry
          raise "Tarball does not contain any theme files"
        end

        Log.debug { "First tarball file entry: #{first_file_entry}" }

        # The tarball contains themes/<theme_name>/...
        parts = first_file_entry.split('/', remove_empty: true)
        Log.debug { "Parts: #{parts.inspect}" }
        if parts.size < 2 || parts[0] != "themes"
          raise "Invalid theme tarball structure. Expected themes/<name>/... structure, got: #{first_file_entry}"
        end

        theme_name = parts[1]

        # Extract the tarball
        Log.info { "Extracting theme..." }
        extract_status = Process.run("tar", ["-xzf", temp_tarball.path])
        unless extract_status.success?
          raise "Failed to extract tarball"
        end

        # Clean up temp file
        File.delete(temp_tarball.path)

        theme_name
      end
    end
  end
end

Nicolino::Commands::Theme.register
