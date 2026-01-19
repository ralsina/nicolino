require "./utils"
require "./theme"
require "tartrazine"
require "lexbor"

module Listings
  include Utils

  # Register output folder to exclude from folder_indexes
  FolderIndexes.register_exclude("listings/")

  # Enable listings feature
  def self.enable(is_enabled : Bool, content_path : Path)
    return unless is_enabled

    listings_dir = begin
      Config.get("listings").as_s
    rescue
      "listings"
    end
    listings_path = content_path / listings_dir
    listings = read_all(listings_path)
    render(listings)
  end

  # Represents a source code file to be syntax-highlighted
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
          "", # Empty language, tartrazine will detect it
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

    # Generate listings CSS file
    render_css

    # Generate listings index page
    render_index(listings)

    # Generate individual listing pages
    listings.each do |listing|
      render_listing(listing)
    end
  end

  def self.render_css
    output_path = Path[Config.options.output] / "css" / "listings.css"

    Croupier::Task.new(
      id: "listings-css",
      output: output_path.to_s,
      inputs: ["conf.yml"],
      mergeable: false,
    ) do
      Log.info { "👉 #{output_path}" }

      # Generate CSS using tartrazine
      formatter = Tartrazine::Html.new(
        theme: Tartrazine.theme("default-dark"),
        line_numbers: false,
        standalone: false,
        surrounding_pre: false
      )

      formatter.style_defs
    end
  end

  def self.render_index(listings : Array(Listing))
    base_path = Path[Config.options.output]
    output_path = (base_path / "listings" / "index.html").normalize.to_s
    page_template = Theme.template_path("page.tmpl")
    title_template = Theme.template_path("title.tmpl")
    item_list_template = Theme.template_path("item_list.tmpl")

    Croupier::Task.new(
      id: "listings-index",
      output: output_path,
      inputs: ["conf.yml", "kv://#{item_list_template}", "kv://#{title_template}", "kv://#{page_template}"],
      mergeable: false
    ) do
      Log.info { "👉 #{output_path}" }

      # Create breadcrumbs for listings index
      breadcrumbs = [{name: "Home", link: "/"}, {name: "Code Listings", link: "/listings/"}] of NamedTuple(name: String, link: String)

      # Include title.tmpl which handles breadcrumbs
      title_html = Templates.environment.get_template(title_template).render({
        "title"       => "Code Listings",
        "link"        => "/listings/",
        "breadcrumbs" => breadcrumbs,
        "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
      })

      # Sort listings by title and build items list
      items = listings.sort_by(&.title).map { |listing|
        {
          link:  "#{listing.title}#{File.extname(listing.source)}.html",
          title: listing.title,
        }
      }

      # Render the item list template
      content = Templates.environment.get_template(item_list_template).render({
        "title"       => "Code Listings",
        "description" => "A collection of source code files with syntax highlighting.",
        "items"       => items,
      })

      # Apply to page template
      html = Render.apply_template(page_template, {
        "content"     => title_html + content,
        "title"       => "Code Listings",
        "breadcrumbs" => breadcrumbs,
      })

      # Process with HTML filters
      doc = Lexbor::Parser.new(html)
      doc = HtmlFilters.make_links_relative(doc, "/listings/")
      HtmlFilters.fix_code_classes(doc).to_html
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
    page_template = Theme.template_path("page.tmpl")
    title_template = Theme.template_path("title.tmpl")
    listing_template = Theme.template_path("listing.tmpl")

    Croupier::Task.new(
      id: "listing:#{listing.source}",
      output: output_path,
      inputs: listing.dependencies + ["kv://#{listing_template}", "kv://#{title_template}", "kv://#{page_template}"],
      mergeable: false
    ) do
      Log.info { "👉 #{output_path}" }

      # Create breadcrumbs for listing page
      breadcrumbs = [{name: "Home", link: "/"}, {name: "Code Listings", link: "/listings/"}] of NamedTuple(name: String, link: String)

      # Include title.tmpl which handles breadcrumbs
      title_html = Templates.environment.get_template(title_template).render({
        "title"       => listing.title,
        "link"        => "",
        "breadcrumbs" => breadcrumbs,
        "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
      })

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
      rendered = Templates.environment.get_template(listing_template).render({
        "title"       => listing.title,
        "code"        => highlighted,
        "raw_content" => HTML.escape(listing.content),
      })

      # Apply to page template
      html = Render.apply_template(page_template, {
        "content"        => title_html + rendered,
        "title"          => listing.title,
        "no_highlightjs" => true,
        "listings_css"   => true,
        "breadcrumbs"    => breadcrumbs,
      })

      # Process with HTML filters
      doc = Lexbor::Parser.new(html)
      doc = HtmlFilters.make_links_relative(doc, "/#{relative_path.rpartition('/')[0]}/")
      HtmlFilters.fix_code_classes(doc).to_html
    end
  end
end
