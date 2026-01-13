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

        # Use filename as title (without extension)
        title = File.basename(filename, File.extname(filename))

        # Tartrazine will auto-detect language from content/extension
        listing = Listing.new(
          source_path.to_s,
          title,
          "",  # Empty language, tartrazine will detect it
          content
        )

        listings << listing
        Log.debug { "Found listing: #{filename}" }
      rescue ex
        Log.warn { "Failed to read listing #{filename}: #{ex.message}" }
      end
    end

    listings
  end

  def self.render(listings : Array(Listing))
    return if listings.empty?

    Log.info { "Generating #{listings.size} code listings" }

    # Generate listings index page
    render_index(listings)

    # Generate individual listing pages
    listings.each do |listing|
      render_listing(listing)
    end
  end

  def self.render_index(listings : Array(Listing))
    base_path = Path[Config.options.output]
    output_path = (base_path / "listings" / "index.html").normalize.to_s

    Croupier::Task.new(
      id: "listings-index",
      output: output_path,
      inputs: ["conf.yml", "kv://templates/listings-index.tmpl", "kv://templates/page.tmpl"],
      mergeable: false
    ) do
      Log.info { "👉 #{output_path}" }

      # Sort listings by title
      sorted_listings = listings.sort_by(&.title)

      # Render the listings index template
      rendered = Templates.environment.get_template("templates/listings-index.tmpl").render({
        "listings" => sorted_listings.map { |l|
          {
            "title" => l.title,
            "link"  => "#{l.title}#{File.extname(l.source)}.html",
          }
        },
      })

      # Apply to page template
      html = Render.apply_template("templates/page.tmpl", {
        "content" => rendered,
        "title"   => "Code Listings",
      })

      # Process with HTML filters
      doc = Lexbor::Parser.new(html)
      doc = HtmlFilters.make_links_relative(doc, "/listings/")
      doc.to_html
    end
  end

  def self.render_listing(listing : Listing)
    base_path = Path[Config.options.output]
    # Remove content path to get relative path
    # Config.options.content may or may not have trailing slash
    content_prefix = Regex.escape(Config.options.content).rchop('/') + "(/|\\\\)?"
    relative_path = listing.source.sub(/^#{content_prefix}/, "")
    # Use full filename with extension for output to avoid conflicts
    output_filename = File.basename(relative_path) + ".html"
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
        # Use tartrazine's auto-detection based on filename
        lexer = Tartrazine.lexer(filename: listing.source)
        highlighted = formatter.format(listing.content, lexer)
      rescue ex
        Log.warn { "Failed to highlight #{listing.title}: #{ex.message}" }
        # Fallback to escaped HTML if highlighting fails
        highlighted = "<pre><code>#{HTML.escape(listing.content)}</code></pre>"
      end

      # Render the listing template
      rendered = Templates.environment.get_template("templates/listing.tmpl").render({
        "title"       => listing.title,
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
end
