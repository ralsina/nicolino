require "./utils"
require "tartrazine"
require "lexbor"

module Listings
  include Utils

  class Listing
    property source : String
    property title : String
    property language : String
    property content : String
    property dependencies : Array(String)

    def initialize(@source, @title, @language, @content)
      @dependencies = [source]
    end
  end

  def self.read_all(listings_path : Path) : Array(Listing)
    listings = [] of Listing

    return listings unless Dir.exists?(listings_path)

    Log.info { "Scanning for code listings in #{listings_path}" }

    # Find all files in listings directory
    Dir.each_child(listings_path) do |filename|
      source_path = listings_path / filename

      # Skip directories and hidden files
      next if File.directory?(source_path) || filename.starts_with?('.')

      # Read file content
      begin
        content = File.read(source_path)

        # Determine language from extension
        language = detect_language(filename)

        # Use filename as title (without extension)
        title = File.basename(filename, File.extname(filename))

        listing = Listing.new(
          source_path.to_s,
          title,
          language,
          content
        )

        listings << listing
        Log.debug { "Found listing: #{filename} (#{language})" }
      rescue ex
        Log.warn { "Failed to read listing #{filename}: #{ex.message}" }
      end
    end

    listings
  end

  def self.render(listings : Array(Listing))
    return if listings.empty?

    Log.info { "Generating #{listings.size} code listings" }

    listings.each do |listing|
      render_listing(listing)
    end
  end

  def self.render_listing(listing : Listing)
    base_path = Path[Config.options.output]
    # Remove content path to get relative path
    # Config.options.content may or may not have trailing slash
    content_prefix = Regex.escape(Config.options.content).rchop('/') + "(/|\\\\)?"
    relative_path = listing.source.sub(/^#{content_prefix}/, "")
    output_filename = File.basename(relative_path, File.extname(relative_path)) + ".html"
    output_path = (base_path / File.dirname(relative_path) / output_filename).normalize.to_s

    Croupier::Task.new(
      id: "listing:#{listing.source}",
      output: output_path,
      inputs: listing.dependencies + ["kv://templates/listing.tmpl", "kv://templates/page.tmpl"],
      mergeable: false
    ) do
      Log.info { "👉 #{output_path}" }

      # Generate syntax-highlighted HTML using tartrazine
      formatter = Tartrazine::Html.new(
        theme: Tartrazine.theme("default-dark"),
        line_numbers: true,
        standalone: false,
        surrounding_pre: true
      )

      begin
        lexer = Tartrazine.lexer(name: listing.language)
        highlighted = formatter.format(listing.content, lexer)
      rescue ex
        Log.warn { "Failed to highlight #{listing.title}: #{ex.message}" }
        # Fallback to escaped HTML if highlighting fails
        highlighted = "<pre><code>#{HTML.escape(listing.content)}</code></pre>"
      end

      # Render the listing template
      rendered = Templates.environment.get_template("templates/listing.tmpl").render({
        "title"       => listing.title,
        "language"    => listing.language,
        "code"        => highlighted,
        "raw_content" => HTML.escape(listing.content),
      })

      # Apply to page template
      html = Render.apply_template("templates/page.tmpl", {
        "content" => rendered,
        "title"   => listing.title,
      })

      # Process with HTML filters
      doc = Lexbor::Parser.new(html)
      doc = HtmlFilters.make_links_relative(doc, "/#{relative_path.rpartition('/')[0]}/")
      doc.to_html
    end
  end

  # Detect programming language from file extension
  def self.detect_language(filename : String) : String
    ext = File.extname(filename).downcase[1..-1] || ""

    # Common language mappings
    case ext
    when "cr"       then "crystal"
    when "py"       then "python"
    when "js"       then "javascript"
    when "ts"       then "typescript"
    when "rb"       then "ruby"
    when "go"       then "go"
    when "rs"       then "rust"
    when "c", "h"   then "c"
    when "cpp", "cc", "cxx", "hpp", "hxx" then "cpp"
    when "java"     then "java"
    when "kt", "kts" then "kotlin"
    when "swift"    then "swift"
    when "sh"       then "bash"
    when "bash"     then "bash"
    when "zsh"      then "zsh"
    when "fish"     then "fish"
    when "php"      then "php"
    when "scala"    then "scala"
    when "html", "htm" then "html"
    when "css"      then "css"
    when "scss"     then "scss"
    when "sass"     then "sass"
    when "xml"      then "xml"
    when "json"     then "json"
    when "yaml", "yml" then "yaml"
    when "sql"      then "sql"
    when "md"       then "markdown"
    when "lua"      then "lua"
    when "r"        then "r"
    when "dart"     then "dart"
    when "ex", "exs" then "elixir"
    when "erl", "hrl" then "erlang"
    when "clj", "cljs" then "clojure"
    when "fs", "fsi", "fsx" then "fsharp"
    when "vb"       then "vb"
    when "pl", "pm" then "perl"
    when "tcl"      then "tcl"
    when "coffee"   then "coffeescript"
    when "tsv"      then "tsv"
    when "csv"      then "csv"
    when "dockerfile" then "docker"
    else "text"
    end
  end
end
