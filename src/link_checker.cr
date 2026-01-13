require "lexbor"
require "log"

# Link checker for validating in-site links
#
# Scans HTML files in the output directory and verifies that
# all in-site links point to existing files.
module LinkChecker
  # Result of checking a single link
  struct LinkResult
    property source_file : String
    property link : String
    property link_type : String
    property status : Symbol # :ok, :broken, :external, :anchor
    property target : String?

    def initialize(@source_file, @link, @link_type, @status, @target = nil)
    end

    def ok?
      @status == :ok
    end

    def broken?
      @status == :broken
    end

    def external?
      @status == :external
    end
  end

  # Check links in a single HTML file
  def self.check_file(html_path : String, existing_files : Set(String)) : Array(LinkResult)
    results = [] of LinkResult

    html_content = File.read(html_path)
    doc = Lexbor::Parser.new(html_content)

    # Check <a href=""> links
    doc.nodes("a").each do |node|
      next unless node.has_key? "href"
      href = node["href"]

      result = check_link(html_path, href, "href", existing_files)
      results << result if result
    end

    # Check <img src=""> links
    doc.nodes("img").each do |node|
      next unless node.has_key? "src"
      src = node["src"]

      result = check_link(html_path, src, "img", existing_files)
      results << result if result
    end

    # Check <link href=""> (stylesheets, etc.)
    doc.nodes("link").each do |node|
      next unless node.has_key? "href"
      href = node["href"]
      rel = node.fetch("rel", "")

      # Skip canonical URLs and non-resource links
      next if rel == "canonical"

      result = check_link(html_path, href, "link", existing_files)
      results << result if result
    end

    # Check <script src=""> links
    doc.nodes("script").each do |node|
      next unless node.has_key? "src"
      src = node["src"]

      result = check_link(html_path, src, "script", existing_files)
      results << result if result
    end

    results
  end

  # Check a single link
  private def self.check_link(source_file : String, link : String, link_type : String, existing_files : Set(String)) : LinkResult?
    # Skip anchors (same-page links)
    if link.starts_with?("#")
      return LinkResult.new(source_file, link, link_type, :anchor, nil)
    end

    # Skip external links
    if link.starts_with?("http://") || link.starts_with?("https://") || link.starts_with?("//")
      return LinkResult.new(source_file, link, link_type, :external, nil)
    end

    # Skip mailto:, tel:, and other protocols
    if link.includes?(":") && !link.starts_with?("/")
      return LinkResult.new(source_file, link, link_type, :external, nil)
    end

    # Convert link to filesystem path
    # Links starting with / are relative to site root
    # Relative links are relative to the source file's directory

    target_path = if link.starts_with?("/")
                    # Absolute link: /foo/bar.html -> output/foo/bar.html
                    link_to_fs_path(link)
                  else
                    # Relative link: bar.html -> output/dir/bar.html
                    source_dir = Path[source_file].parent
                    resolve_relative_link(source_dir.to_s, link)
                  end

    # Handle anchors in links (e.g., /page.html#section)
    base_target = target_path.split("#")[0]

    # Check if target exists
    if existing_files.includes?(base_target)
      LinkResult.new(source_file, link, link_type, :ok, base_target)
    else
      LinkResult.new(source_file, link, link_type, :broken, base_target)
    end
  end

  # Convert a site-relative link to filesystem path
  private def self.link_to_fs_path(link : String) : String
    # Remove leading slash and add output prefix
    link = link.lchop("/")
    path = Path["output", link].to_s

    # If link doesn't have an extension and is a directory,
    # try index.html
    if !path.includes?(".") || File.extname(path) == ""
      if File.directory?(path)
        path = Path[path, "index.html"].to_s
      elsif !File.exists?(path)
        # Try with .html extension
        path_with_ext = path + ".html"
        path = path_with_ext if File.exists?(path_with_ext)
      end
    end

    path
  end

  # Resolve a relative link based on source directory
  private def self.resolve_relative_link(source_dir : String, link : String) : String
    base_path = Path[source_dir, link].normalize.to_s

    # If result escapes output directory, treat as broken
    if !base_path.starts_with?("output/")
      return base_path
    end

    # Handle directories (try index.html)
    if File.directory?(base_path)
      base_path = Path[base_path, "index.html"].to_s
    elsif !base_path.includes?(".")
      # No extension, try .html
      base_path = base_path + ".html"
    end

    base_path
  end

  # Check all HTML files in the output directory
  def self.check_all(output_dir : String = "output") : Array(LinkResult)
    Log.info { "Checking links in #{output_dir}/" }

    # Build set of all existing files
    existing_files = Set(String).new
    Dir.glob("#{output_dir}/**/*").each do |path|
      next if File.directory?(path)
      existing_files << path
    end

    Log.debug { "Found #{existing_files.size} files in output" }

    all_results = [] of LinkResult

    # Find all HTML files
    html_files = Dir.glob("#{output_dir}/**/*.html")
    Log.info { "Checking #{html_files.size} HTML files" }

    html_files.each do |html_file|
      results = check_file(html_file, existing_files)
      all_results.concat(results)
    end

    all_results
  end

  # Print summary of link check results
  def self.print_summary(results : Array(LinkResult))
    broken = results.select(&.broken?)
    external = results.select(&.external?)
    anchors = results.select(&.status.==(:anchor))
    ok = results.select(&.ok?)

    Log.info { "Link check results:" }
    Log.info { "  ✓ OK: #{ok.size}" }
    Log.info { "  ⊘ External: #{external.size}" }
    Log.info { "  ⚓ Anchor: #{anchors.size}" }
    Log.info { "  ✗ Broken: #{broken.size}" }

    if broken.size > 0
      Log.error { "" }
      Log.error { "Broken links:" }
      broken.each do |result|
        Log.error { "  #{result.source_file}" }
        Log.error { "    #{result.link_type}: #{result.link}" }
        Log.error { "    → Target not found: #{result.target}" }
        Log.error { "" }
      end
    end

    broken.size
  end
end
